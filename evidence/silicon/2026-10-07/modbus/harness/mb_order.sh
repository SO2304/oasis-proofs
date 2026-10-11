#!/usr/bin/env bash
# mb_order.sh <label> <seq> <fc> <start_hex> <v1,v2,..> [validity_ms=9000] [unit_hex=11] [gw_id=1] [boot_id override]
# Phase 1.4: read the gateway's clock (C `@G`: boot_id, now_ms), build an OMB1 order
# with deadline = now_ms + validity (oasis_enroll mb-order), save it to
# payloads/<label>.hex, have B originate it (`@P`), capture A, B and C (mb_send.sh),
# then append A's counters (`@D`) to <label>_A.log.
label="$1"; seq="$2"; fc="$3"; start="$4"; vals="$5"; validity="${6:-9000}"; unit="${7:-11}"; gw="${8:-1}"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
EV=/c/dev/oasis/evidence/silicon/2026-10-07/modbus
T=/c/dev/oasis/target/debug/examples/oasis_enroll.exe
st=$(timeout 8 bash "$SC/send_read.sh" /dev/ttyS10 $'@G\n' 2 2>/dev/null | grep MB_GW_STATUS)
boot=$(echo "$st" | grep -oE 'boot_id=[0-9]+' | cut -d= -f2)
now=$(echo "$st" | grep -oE 'now_ms=[0-9]+' | cut -d= -f2)
[ -n "$9" ] && boot="$9"
[ -z "$boot" ] || [ -z "$now" ] && { echo "no gateway status"; exit 2; }
deadline=$(( now + validity ))
hex=$($T mb-order "$gw" "$seq" "$boot" "$deadline" "$unit" "$fc" "$start" "$vals" 2> "$EV/payloads/$label.txt")
echo "$hex" > "$EV/payloads/$label.hex"
echo "# gateway clock before: $st" >> "$EV/payloads/$label.txt"
bash "$SC/mb_send.sh" "$label" B "@P$hex" "$EV"
timeout 8 bash "$SC/send_read.sh" /dev/ttyS8 $'@D\n' 2 2>/dev/null >> "$EV/${label}_A.log"
for b in B C A; do
  grep -hE "PAYLOAD_TX|ARRIVED|DROP|MB_GW|MB_DEV" "$EV/${label}_$b.log" | cut -d'|' -f2,4,5 | cut -c1-230
done
