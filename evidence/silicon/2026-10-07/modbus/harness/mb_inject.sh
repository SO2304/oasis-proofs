#!/usr/bin/env bash
# mb_inject.sh <label> <board> <line>
# Phase 1.4: send one line to a board (mb_send.sh, capture A, B, C), then append A's
# counters (`@D`) to <label>_A.log and print the relevant lines.
label="$1"; board="$2"; line="$3"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
EV=/c/dev/oasis/evidence/silicon/2026-10-07/modbus
bash "$SC/mb_send.sh" "$label" "$board" "$line" "$EV"
timeout 8 bash "$SC/send_read.sh" /dev/ttyS8 $'@D\n' 2 2>/dev/null >> "$EV/${label}_A.log"
for b in B C A; do
  grep -hE "INJECT|PAYLOAD_TX|ARRIVED|DROP|FRAMER|MB_GW|MB_DEV|V0B" "$EV/${label}_$b.log" | cut -d'|' -f2,4,5 | cut -c1-230
done
