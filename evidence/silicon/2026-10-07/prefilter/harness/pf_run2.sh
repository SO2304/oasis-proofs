#!/usr/bin/env bash
# pf_run2.sh <label> <c_mode> <budget> <flood> <b_mode>
# Phase 2.1 availability bench, v14+. Drains C's USB during the run (a blocked log on an
# unread port stalls the main loop and overflows the ISR ring — runs 61/62).
set -u
L="$1"; CM="$2"; BUD="$3"; FLOOD="$4"; BM="$5"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
EV=/c/dev/oasis/evidence/silicon/2026-10-07/prefilter
send(){ timeout 10 bash "$SC/send_read.sh" "$1" "$2"$'\n' 2 2>/dev/null; }
: > "$EV/${L}_C.log"; : > "$EV/${L}_B.log"
send /dev/ttyS10 "$CM"     >> "$EV/${L}_C.log"
send /dev/ttyS10 "@D$BUD"  >> "$EV/${L}_C.log"
send /dev/ttyS10 '@S1'     >> "$EV/${L}_C.log"
send /dev/ttyS9  "$BM"     >> "$EV/${L}_B.log"
send /dev/ttyS9  '@S1'     >> "$EV/${L}_B.log"
grep -q 'PF_MODE' "$EV/${L}_C.log" && grep -q 'PF_MODE' "$EV/${L}_B.log" || { echo "ABORT $L: mode not confirmed"; exit 2; }
secs=$(echo "$FLOOD" | cut -d, -f2)
# keep C's USB drained for the whole run
timeout $(( secs + 80 )) bash "$SC/read_dev.sh" /dev/ttyS10 $(( secs + 75 )) >> "$EV/${L}_C.log" 2>/dev/null &
drain=$!
timeout $(( secs + 90 )) bash "$SC/send_read.sh" /dev/ttyS9 "@Y$FLOOD"$'\n' $(( secs + 70 )) 2>/dev/null >> "$EV/${L}_B.log"
kill $drain 2>/dev/null; wait $drain 2>/dev/null
send /dev/ttyS10 '@B'  >> "$EV/${L}_C.log"
send /dev/ttyS10 '@S0' >> "$EV/${L}_C.log"
printf '%s\n  B: %s\n  C: %s\n' "$L" "$(grep -h PF_FLOOD_DONE "$EV/${L}_B.log" | cut -d'|' -f5)" "$(grep -h PF_STATUS "$EV/${L}_C.log" | tail -1 | cut -d'|' -f5)"
