#!/usr/bin/env bash
# MY SIDE (Hermes container) — wait for the tunnel, then enter the HUT.
# Read-only. Nothing is disabled here.
set -uo pipefail
PT="$(dirname "$0")/platform-tools"
[ -x "$PT/adb" ] || PT="/opt/data/cache/scratch/pt/platform-tools"
ADB="$PT/adb"
HOST=172.16.0.1
PORT="${1:-5555}"

echo "====================================================="
echo " waiting for the tunnel on $HOST:$PORT ..."
echo "====================================================="
for i in $(seq 1 40); do
  if timeout 2 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
    echo "  [ok] tunnel is UP (after $((i*3))s)"; break
  fi
  [ "$i" = 40 ] && { echo "  [x] no tunnel after 120s. Nothing to connect to."; exit 1; }
  sleep 3
done

"$ADB" kill-server >/dev/null 2>&1
"$ADB" start-server >/dev/null 2>&1
"$ADB" connect "$HOST:$PORT"
echo
echo "--- devices ---"
"$ADB" devices -l
echo
echo "--- if it says 'device', I am IN. Probing read-only: ---"
"$ADB" shell getprop ro.product.model 2>/dev/null
"$ADB" shell getprop ro.build.version.release 2>/dev/null
echo "packages: $("$ADB" shell pm list packages 2>/dev/null | wc -l)"
