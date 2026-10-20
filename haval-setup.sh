#!/usr/bin/env bash
# Put the Haval HUT toolkit on this computer and check it is ready.
#   bash haval-setup.sh
set -uo pipefail

DEST="${DEST:-$HOME/Documents/haval-hut}"
BASE="https://bassam133.github.io/haval-hut-clean"
FILES="SPECS.md CLEAN-SHEET.txt VEHICLE.txt PROMPT.txt START-HERE.txt hut-remote.sh hut-pair.sh hut-scan.sh hut-clean.sh hut-restore.sh remove.txt SETUP.md GUIDE.md"

echo "====================================================="
echo " Haval HUT toolkit -> $DEST"
echo "====================================================="

command -v curl >/dev/null || { echo "curl is missing - cannot download. Install Xcode command line tools."; exit 1; }
mkdir -p "$DEST" || { echo "Could not create $DEST"; exit 1; }
cd "$DEST" || exit 1

FAIL=0
for f in $FILES; do
  if curl -fsSL --max-time 60 -o "$f" "$BASE/$f"; then
    printf '  ok    %-16s %6s bytes\n' "$f" "$(wc -c < "$f" | tr -d ' ')"
  else
    printf '  FAIL  %-16s\n' "$f"; FAIL=$((FAIL + 1))
  fi
done

[ "$FAIL" -eq 0 ] || { echo; echo "$FAIL file(s) failed. Are you online?"; exit 1; }

chmod +x hut-pair.sh hut-scan.sh hut-clean.sh hut-restore.sh 2>/dev/null
[ -f SETUP.md ] || { echo "SETUP.md missing"; exit 1; }

# the scripts must not contain destructive commands - verify what actually arrived
echo
echo "-- safety check on the downloaded scripts --"
if grep -qE '(^|[^a-z])adb +(uninstall|push|install)|rm -rf|pin|fastboot' hut-clean.sh hut-scan.sh 2>/dev/null; then
  echo "  WARNING: found a command that changes data unexpectedly - do NOT run these."
  exit 1
else
  echo "  clean: no uninstall / push / rm -rf / fastboot anywhere"
fi

echo
echo "-- adb --"
if command -v adb >/dev/null 2>&1; then
  echo "  adb found: $(command -v adb)"
  adb version 2>/dev/null | head -1
elif [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
  echo "  adb found: $HOME/Library/Android/sdk/platform-tools/adb"
elif command -v brew >/dev/null 2>&1; then
  echo "  adb is MISSING. Install it now with:"
  echo "      brew install --cask android-platform-tools"
  echo "  (then run 'adb version' to confirm)"
else
  echo "  adb is MISSING and Homebrew was not found."
  echo "  Download platform-tools instead: https://developer.android.com/tools/releases/platform-tools"
fi

echo
echo "====================================================="
echo " Ready. Next:"
echo "   1. read      $DEST/SETUP.md"
echo "   2. in the car, open the head unit's engineering menu"
echo "      (bottom-left corner once, then 10 quick taps top-left)"
echo "   3. pair      cd \"$DEST\" && bash hut-pair.sh"
echo "   4. scan      cd \"$DEST\" && bash hut-scan.sh"
echo "   5. send me the hut-report-....txt it writes"
echo "====================================================="
