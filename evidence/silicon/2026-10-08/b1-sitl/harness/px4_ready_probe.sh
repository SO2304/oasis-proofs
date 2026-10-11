#!/usr/bin/env bash
# px4_ready_probe.sh — start PX4 SITL (SIH quadx) alone and time how long it takes to
# report that it is actually armable. Writes only under $HOME/b1-sitl.
set -u
PX4D="$HOME/PX4-Autopilot"
OUT="$HOME/b1-sitl"
LOG="$OUT/ready_probe.log"
case "$OUT" in "$HOME"/*) ;; *) echo "refus"; exit 3;; esac
mkdir -p "$OUT/probe_run"

pkill -f 'bin/px4' 2>/dev/null; sleep 1
( cd "$OUT/probe_run"
  PX4_SYS_AUTOSTART=10040 "$PX4D/build/px4_sitl_default/bin/px4" \
    -d "$PX4D/build/px4_sitl_default/etc" > "$LOG" 2>&1 ) &
PID=$!

t=0
ready=0
while [ "$t" -lt 120 ]; do
  if grep -q "Ready for takeoff" "$LOG" 2>/dev/null; then ready=$t; break; fi
  sleep 1; t=$((t+1))
done

if [ "$ready" -gt 0 ] || grep -q "Ready for takeoff" "$LOG" 2>/dev/null; then
  echo "ARMABLE apres ${ready}s"
else
  echo "PAS ARMABLE en ${t}s"
fi
echo "--- etats de sante vus ---"
grep -iE "preflight|health|Ready for takeoff|heading|denied" "$LOG" | sort -u | head -12
kill $PID 2>/dev/null; pkill -f 'bin/px4' 2>/dev/null
