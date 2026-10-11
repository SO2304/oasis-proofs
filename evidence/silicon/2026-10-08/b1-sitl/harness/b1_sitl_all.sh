#!/usr/bin/env bash
# b1_sitl_all.sh — run the five B1 cases one after another and print a summary table.
set -u
OUT="$HOME/b1-sitl"
for c in valid forged tamper replay revoked; do
  echo "############################################################ $c"
  bash "$HOME/b1_sitl_run.sh" "$c" 1 2>&1 | tail -16
  echo
done

echo "############################################################ RESUME"
printf '%-9s %-28s %-22s %s\n' CAS "DECISION OASIS" "TRAME ARM" "PX4"
for c in valid forged tamper replay revoked; do
  v="$OUT/${c}_vehicle.log"; p="$OUT/${c}_px4.log"
  dec=$(grep -ahoE 'GATE (Act|Reject\([A-Za-z]+\))|MESH_DROP why="[^"]+"' "$v" 2>/dev/null | head -2 | tr '\n' ';')
  frame=$(grep -ac 'COMMAND_LONG(400) sent' "$v" 2>/dev/null || echo 0)
  armed=$(grep -ac 'Armed by external command' "$p" 2>/dev/null || echo 0)
  seen=$(grep -ac 'PX4 ARMED' "$v" 2>/dev/null || echo 0)
  printf '%-9s %-28s %-22s %s\n' "$c" "${dec:-?}" "${frame} trame(s)" "armed=${armed} vu_par_le_vehicule=${seen}"
done
