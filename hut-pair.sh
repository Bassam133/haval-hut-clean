#!/usr/bin/env bash
# Pair this laptop with the car head unit over ADB and prove the link works.
# Read-only: it never changes anything on the unit.
#   bash hut-pair.sh
set -uo pipefail
cd "$(dirname "$0")"

find_adb() {
  for c in "$(command -v adb 2>/dev/null)" \
           "${HOME:-/nonexistent}/Library/Android/sdk/platform-tools/adb" \
           "/opt/homebrew/bin/adb" "/usr/local/bin/adb" "./platform-tools/adb"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

ADB="$(find_adb)" || {
  echo "adb is not installed."
  echo "  macOS : brew install --cask android-platform-tools"
  echo "  or download: https://developer.android.com/tools/releases/platform-tools"
  exit 1
}
echo "adb: $ADB"
"$ADB" version | head -1

echo
echo "== checklist before this can work =="
cat <<'EOF'
  1. head unit has the FULL engineering menu (production mode on + unit rebooted)
  2. inside it: ADB / USB debug enabled
  3. inside it: USB mode switching -> Peripheral  (not Host)
  4. a real DATA cable (not charge-only), USB-A on the unit side
  5. screen unlocked / awake
EOF
echo
printf 'Press Enter when all five are true (Ctrl-C to stop)... '
read -r _ || true

# a stale server is the most common cause of "no devices"
"$ADB" kill-server >/dev/null 2>&1
"$ADB" start-server >/dev/null 2>&1

echo
echo "== watching for the unit (up to 3 minutes) =="
echo "   if a prompt appears ON THE CAR SCREEN, tap Allow (tick 'always')"
waited=0; LAST=""
while :; do
  OUT="$("$ADB" devices 2>/dev/null | tr -d '\r' | sed '1d' | grep -v '^$')"
  STATE="$(printf '%s' "$OUT" | awk '{print $2}' | head -1)"
  SERIAL="$(printf '%s' "$OUT" | awk '{print $1}' | head -1)"

  case "$STATE" in
    device)   break ;;
    unauthorized)
      if [ "$LAST" != "unauthorized" ]; then
        echo "   unit seen but UNAUTHORIZED - a prompt is waiting on the car screen."
        echo "   Tap Allow there (tick 'always allow'). Waiting..."
        LAST="unauthorized"
      fi ;;
    *)
      if [ "$waited" -ge 180 ]; then
        echo
        echo "FAILED: no unit appeared after 180s."
        echo "  - Is the cable a DATA cable? Charge-only cables never work."
        echo "  - Is USB mode switched to Peripheral inside the menu?"
        echo "  - Try another USB port on the laptop (avoid hubs)."
        echo "  - MacBook USB-C: use a direct USB-A adapter, not a hub."
        echo "Nothing was changed on the unit."
        exit 1
      fi ;;
  esac
  sleep 3; waited=$((waited + 3))
done

echo
echo "PAIRED. serial: $SERIAL"
echo
echo "== proving the link (read-only) =="
MODEL="$("$ADB" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
BUILD="$("$ADB" shell getprop ro.build.display.id 2>/dev/null | tr -d '\r')"
REL="$("$ADB" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
PKGS="$("$ADB" shell pm list packages 2>/dev/null | tr -d '\r' | grep -c .)"
THIRD="$("$ADB" shell pm list packages -3 2>/dev/null | tr -d '\r' | grep -c .)"
printf '  %-18s %s\n' model "$MODEL"
printf '  %-18s %s\n' android "$REL"
printf '  %-18s %s\n' build "$BUILD"
printf '  %-18s %s\n' packages "$PKGS"
printf '  %-18s %s\n' third-party "$THIRD"
echo
if [ -z "$MODEL" ] && [ "$PKGS" = "0" ]; then
  echo "Connected, but 'shell' returned nothing. The unit may need a second:" 
  echo "      $ADB kill-server && $ADB start-server && $ADB devices"
else
  echo "Link works. Next:  bash hut-scan.sh   (writes the full report)"
fi
