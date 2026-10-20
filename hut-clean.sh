#!/usr/bin/env bash
# Disable (NOT uninstall) the packages listed in remove.txt, on a Haval/GWM head unit.
# Every package's previous state is written to a record first, so hut-restore.sh can undo it.
#   bash hut-clean.sh            # uses remove.txt
#   bash hut-clean.sh mylist.txt
set -uo pipefail
cd "$(dirname "$0")"

LIST="${1:-remove.txt}"
RECORD="hut-record.txt"

# Packages that must never be touched, whatever the list says.
PROTECTED='(^android$|^com\.android\.|^com\.google\.android\.(gms|gsf|vending)|^com\.gwm|^com\.haval|^com\.greatwall|^com\.mediatek|^com\.qualcomm|^com\.nvidia|^com\.nxp|^vendor\.|^com\.svox|inputmethod|launcher|systemui|telephony|telecom|bluetooth|hvac|settings|providers|packageinstaller|permissioncontroller|networkstack|car\.|hardware\.)'

find_adb() {
  for c in "$(command -v adb 2>/dev/null)" \
           "${HOME:-/nonexistent}/Library/Android/sdk/platform-tools/adb" \
           "/opt/homebrew/bin/adb" "/usr/local/bin/adb" "./platform-tools/adb"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

[ -f "$LIST" ] || { echo "No $LIST found. Create it with one package name per line (see hut-scan report)."; exit 1; }

# ---- 1. validate the WHOLE list before touching the device -------------------
PKGS=(); BLOCKED=(); SKIPPED=()
while IFS= read -r raw; do
  line="${raw%%#*}"; line="$(printf '%s' "$line" | tr -d ' \r\t')"
  [ -z "$line" ] && continue
  if printf '%s' "$line" | grep -Eq "$PROTECTED"; then BLOCKED+=("$line"); else PKGS+=("$line"); fi
done < "$LIST"

if [ "${#BLOCKED[@]}" -gt 0 ]; then
  echo "REFUSED - these are protected (system / car-critical) and were NOT disabled:"
  for b in "${BLOCKED[@]}"; do echo "   $b"; done
  echo
  echo "Remove them from $LIST and run again. Nothing was changed."
  exit 2
fi
[ "${#PKGS[@]}" -gt 0 ] || { echo "Nothing left to do: $LIST has no usable package names."; exit 1; }

echo "About to DISABLE ${#PKGS[@]} package(s):"
for p in "${PKGS[@]}"; do echo "   $p"; done
echo
printf 'Type exactly  DISABLE  to continue: '
read -r OK
[ "$OK" = "DISABLE" ] || { echo "Cancelled. Nothing was changed."; exit 0; }

# ---- 2. connect -------------------------------------------------------------
ADB="$(find_adb)" || { echo "adb not found (macOS: brew install --cask android-platform-tools)"; exit 1; }
waited=0; STATE="$("$ADB" get-state 2>/dev/null)"
while [ "$STATE" != "device" ]; do
  [ "$waited" -ge 120 ] && { echo "No device (state: '${STATE:-none}'). Nothing was changed."; exit 1; }
  sleep 2; waited=$((waited + 2)); STATE="$("$ADB" get-state 2>/dev/null)"
done

SERIAL="$("$ADB" get-serialno)"
INSTALLED="$("$ADB" shell pm list packages 2>/dev/null | tr -d '\r' | sed 's/^package://' | sort)"

# record file keeps a header per device so the same unit is never recorded twice
if ! grep -q "^# device $SERIAL" "$RECORD" 2>/dev/null; then
  {
    echo "# device $SERIAL"
    echo "# created $(date)"
    echo "# format: <package><TAB><state-before>"
  } >> "$RECORD"
else
  echo "NOTE: $RECORD already has a record for this device - new entries are appended."
fi

printf '%-46s %-12s %s\n' PACKAGE BEFORE RESULT
DONE=0
for p in "${PKGS[@]}"; do
  if ! printf '%s\n' "$INSTALLED" | grep -qx "$p"; then
    printf '%-46s %-12s %s\n' "$p" "-" "not installed (skipped)"; continue
  fi
  BEFORE="enabled"
  printf '%s\n' "$("$ADB" shell pm list packages -d 2>/dev/null | tr -d '\r')" | grep -qx "package:$p" && BEFORE="disabled"
  if [ "$BEFORE" = "disabled" ]; then
    printf '%-46s %-12s %s\n' "$p" "disabled" "already disabled (skipped)"; continue
  fi
  OUT="$("$ADB" shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r')"
  if printf '%s' "$OUT" | grep -qi 'new state: disabled'; then
    printf '%s\t%s\n' "$p" "$BEFORE" >> "$RECORD"
    printf '%-46s %-12s %s\n' "$p" "$BEFORE" "DISABLED"; DONE=$((DONE + 1))
  else
    printf '%-46s %-12s %s\n' "$p" "$BEFORE" "FAILED: ${OUT:0:60}"
  fi
done

echo
echo "Disabled $DONE package(s). Nothing was uninstalled - every one can be re-enabled."
echo "Record: $(pwd)/$RECORD"
echo "Undo with:  bash hut-restore.sh"
echo
echo "Reboot the unit to see the clean home screen: (optional)"
echo "   $ADB reboot"
