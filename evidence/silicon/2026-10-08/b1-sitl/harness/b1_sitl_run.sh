#!/usr/bin/env bash
# b1_sitl_run.sh — B1 on PX4 SITL, one case per invocation, all inside WSL.
#
#   PX4 SITL (SIH quadx: physics inside PX4, no Java, no Gazebo)
#        ▲ COMMAND_LONG(400)                 ▲ HEARTBEAT (armed bit read back)
#        │                                    │
#   px4_order_arm vehicle  ◀──V2_EXTENSION── px4_order_arm commander
#
# The first version fired the order 5 s after boot, before the EKF had a heading
# reference, so PX4 denied arming for its own reasons and the test said nothing about
# OASIS. This one waits for PX4 to report "Ready for takeoff" — i.e. actually armable —
# before the commander speaks. Writes only under $OUT.
set -u
PX4D="$HOME/PX4-Autopilot"
BIN="$HOME/oasis-kani/target/release/px4_order_arm"
OUT="$HOME/b1-sitl"
V="$HOME/px4-venv"
CASE="${1:?usage: b1_sitl_run.sh <valid|forged|tamper|replay|revoked> [seq]}"
SEQ="${2:-1}"
BOOT=4242
READY_CAP=150

case "$OUT" in "$HOME"/*) ;; *) echo "refus: OUT=$OUT"; exit 3;; esac
[ -x "$BIN" ] || { echo "binaire absent: $BIN"; exit 2; }
[ -x "$PX4D/build/px4_sitl_default/bin/px4" ] || { echo "px4 non construit"; exit 2; }
mkdir -p "$OUT"
export PATH="$V/bin:$PATH"

PXLOG="$OUT/${CASE}_px4.log"

pkill -f 'bin/px4' 2>/dev/null; sleep 1
rm -rf "$OUT/px4_run"; mkdir -p "$OUT/px4_run"
( cd "$OUT/px4_run"
  # The airframe sets PX4_SIMULATOR=sihsim and PX4_SIM_MODEL=quadx itself, and enables
  # SENS_EN_GPSSIM / BAROSIM / MAGSIM, so the EKF gets a fix on its own.
  PX4_SYS_AUTOSTART=10040 "$PX4D/build/px4_sitl_default/bin/px4" \
    -d "$PX4D/build/px4_sitl_default/etc" > "$PXLOG" 2>&1 ) &
PX4PID=$!

t=0
while [ "$t" -lt "$READY_CAP" ]; do
  grep -q "Ready for takeoff" "$PXLOG" 2>/dev/null && break
  sleep 1; t=$((t+1))
done
if ! grep -q "Ready for takeoff" "$PXLOG" 2>/dev/null; then
  echo "PX4 JAMAIS ARMABLE en ${t}s — le test ne dirait rien d OASIS, on arrete"
  grep -iE "preflight|health|denied" "$PXLOG" | sort -u | head -8
  kill $PX4PID 2>/dev/null; pkill -f 'bin/px4' 2>/dev/null
  exit 4
fi
echo "PX4 ARMABLE apres ${t}s (Ready for takeoff)"

VEHARGS=(vehicle --listen 127.0.0.1:14560 --px4 127.0.0.1:18570 --boot-id "$BOOT" --seconds 20)
[ "$CASE" = "revoked" ] && VEHARGS+=(--revoked)
"$BIN" "${VEHARGS[@]}" > "$OUT/${CASE}_vehicle.log" 2>&1 &
VEHPID=$!
sleep 3

CMDCASE="$CASE"
[ "$CASE" = "revoked" ] && CMDCASE="valid"   # a genuine order from an origin the vehicle revoked
"$BIN" commander --to 127.0.0.1:14560 --case "$CMDCASE" --seq "$SEQ" --boot-id "$BOOT" \
  > "$OUT/${CASE}_commander.log" 2>&1

wait $VEHPID 2>/dev/null
kill $PX4PID 2>/dev/null; pkill -f 'bin/px4' 2>/dev/null

echo
echo "===== $CASE ====="
echo "--- commander ---"; cat "$OUT/${CASE}_commander.log"
echo "--- vehicle ---";   cat "$OUT/${CASE}_vehicle.log"
echo "--- px4 : armement ---"
grep -iE "Armed by|Disarmed|arming denied|rejected" "$PXLOG" | tail -6 || echo "(aucune ligne d armement)"
