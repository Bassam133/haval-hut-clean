#!/usr/bin/env bash
# READ-ONLY scan of a Haval / GWM head unit (HUT) over ADB.
# It changes NOTHING: no install, no uninstall, no disable, no write.
#   bash hut-scan.sh
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
  echo "adb was not found. Install it, then run this again:"
  echo "  macOS : brew install --cask android-platform-tools"
  echo "  Linux : sudo apt install android-tools-adb"
  exit 1
}
echo "using: $ADB"
"$ADB" version | head -1

echo
echo "== waiting for the head unit (plug in / connect while the HUT has ADB enabled) =="
# NOT 'timeout': macOS does not ship it (that is gtimeout from coreutils).
waited=0
STATE="$("$ADB" get-state 2>/dev/null)"
while [ "$STATE" != "device" ]; do
  if [ "$waited" -ge 120 ]; then
    echo "No device appeared within 120s (last state: '${STATE:-none}'). Nothing was done."
    echo "  - If the state is 'unauthorized', accept the prompt on the head unit."
    echo "  - If it is empty, the cable/USB mode or the ADB toggle is not ready yet."
    exit 1
  fi
  sleep 2; waited=$((waited + 2))
  STATE="$("$ADB" get-state 2>/dev/null)"
done

DEV="$("$ADB" get-serialno 2>/dev/null)"
echo "device: $DEV  state: $STATE"
[ "$STATE" = "device" ] || { echo "Device is not in 'device' state (it may be 'unauthorized': accept the prompt on the screen). Nothing was done."; exit 1; }

REPORT="hut-report-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "# Haval HUT read-only scan"
  echo "# date: $(date)"
  echo "# serial: $DEV"
  echo
  echo "===== IDENTITY ====="
  for p in ro.product.model ro.product.name ro.product.device ro.product.brand \
           ro.build.version.release ro.build.version.sdk ro.build.display.id \
           ro.build.fingerprint ro.product.locale ro.serialno; do
    printf '%-28s %s\n' "$p" "$("$ADB" shell getprop "$p" 2>/dev/null | tr -d '\r')"
  done
  echo
  echo "===== THIRD-PARTY PACKAGES (installed apps) ====="
  "$ADB" shell pm list packages -3 -f 2>/dev/null | tr -d '\r' | sort
  echo
  echo "===== SYSTEM PACKAGES ====="
  "$ADB" shell pm list packages -s 2>/dev/null | tr -d '\r' | sort
  echo
  echo "===== ALREADY DISABLED PACKAGES ====="
  "$ADB" shell pm list packages -d 2>/dev/null | tr -d '\r' | sort
  echo
  echo "===== ENABLED (not system) ====="
  "$ADB" shell pm list packages -e -3 2>/dev/null | tr -d '\r' | sort
  echo
  echo "===== COUNTS ====="
  printf 'third-party : %s\n' "$("$ADB" shell pm list packages -3 2>/dev/null | tr -d '\r' | grep -c .)"
  printf 'system      : %s\n' "$("$ADB" shell pm list packages -s 2>/dev/null | tr -d '\r' | grep -c .)"
  printf 'disabled    : %s\n' "$("$ADB" shell pm list packages -d 2>/dev/null | tr -d '\r' | grep -c .)"
} > "$REPORT" 2>&1

echo
echo "DONE - nothing on the unit was changed."
echo "Report written to: $(pwd)/$REPORT"
echo "Send that file back for the next step."
echo
echo "===== QUICK PREVIEW ====="
head -20 "$REPORT"
