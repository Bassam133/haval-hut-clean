#!/usr/bin/env bash
# Undo hut-clean.sh: re-enable ONLY the packages that script disabled itself.
# Packages that were already disabled before, or disabled by someone else, are left alone.
#   bash hut-restore.sh
set -uo pipefail
cd "$(dirname "$0")"

RECORD="hut-record.txt"

find_adb() {
  for c in "$(command -v adb 2>/dev/null)" \
           "${HOME:-/nonexistent}/Library/Android/sdk/platform-tools/adb" \
           "/opt/homebrew/bin/adb" "/usr/local/bin/adb" "./platform-tools/adb"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

[ -f "$RECORD" ] || { echo "No $RECORD found - nothing was ever disabled by hut-clean.sh here."; exit 1; }

ADB="$(find_adb)" || { echo "adb not found (macOS: brew install --cask android-platform-tools)"; exit 1; }
waited=0; STATE="$("$ADB" get-state 2>/dev/null)"
while [ "$STATE" != "device" ]; do
  [ "$waited" -ge 120 ] && { echo "No device (state: '${STATE:-none}'). Nothing was changed."; exit 1; }
  sleep 2; waited=$((waited + 2)); STATE="$("$ADB" get-state 2>/dev/null)"
done
SERIAL="$("$ADB" get-serialno)"

# only the section belonging to the connected unit
SECTION="$(awk -v s="# device $SERIAL" '$0==s{on=1;next} /^# device /{on=0} on && $0 !~ /^#/ && NF {print $1}' "$RECORD")"
if [ -z "$SECTION" ]; then
  echo "The record has no entries for device $SERIAL. Nothing to restore."
  echo "Records present for: $(grep -c '^# device ' "$RECORD") device(s)."
  exit 0
fi

echo "Re-enabling these packages on $SERIAL:"
printf '   %s\n' $SECTION
printf 'Type exactly  RESTORE  to continue: '
read -r OK
[ "$OK" = "RESTORE" ] || { echo "Cancelled. Nothing was changed."; exit 0; }

printf '%-46s %s\n' PACKAGE RESULT
for p in $SECTION; do
  OUT="$("$ADB" shell pm enable "$p" 2>&1 | tr -d '\r')"
  if printf '%s' "$OUT" | grep -qiE 'new state: enabled|enabled'; then
    printf '%-46s %s\n' "$p" "ENABLED"
  else
    printf '%-46s %s\n' "$p" "FAILED: ${OUT:0:60}"
  fi
done

# keep the record (it is the audit trail); mark it applied
echo "# restored $(date)" >> "$RECORD"
echo
echo "Done. Reboot the unit if a tile is still missing: $ADB reboot"
