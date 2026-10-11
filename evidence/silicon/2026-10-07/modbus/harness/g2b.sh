#!/usr/bin/env bash
# g2b.sh <label> <seq> <value> : Phase 1.4 G2b. B signs an OMB1 order and keeps it (@H);
# then, in one capture session, sends a copy with the value byte flipped (@K130, a
# counter C has never seen) and 1.5 s later the genuine envelope (z). LF-only logs.
label="$1"; seq="$2"; val="$3"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
EV=/c/dev/oasis/evidence/silicon/2026-10-07/modbus
T=/c/dev/oasis/target/debug/examples/oasis_enroll.exe
st=$(timeout 8 bash "$SC/send_read.sh" /dev/ttyS10 $'@G\n' 2 2>/dev/null | grep MB_GW_STATUS)
boot=$(echo "$st" | grep -oE 'boot_id=[0-9]+' | cut -d= -f2); now=$(echo "$st" | grep -oE 'now_ms=[0-9]+' | cut -d= -f2)
hex=$($T mb-order 1 "$seq" "$boot" $(( now + 9500 )) 11 6 10 "$val" 2> "$EV/payloads/$label.txt")
echo "$hex" > "$EV/payloads/$label.hex"; echo "# gateway clock before: $st" >> "$EV/payloads/$label.txt"
W=8
for b in A C; do
  timeout $(( W + 3 )) bash "$SC/read_dev.sh" "/dev/ttyS$([ $b = A ] && echo 8 || echo 10)" $(( W + 1 )) > "$EV/${label}_${b}.log" 2>/dev/null &
done
sleep 1.5
dev=/dev/ttyS9; stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null; exec 3<>"$dev"; : > "$EV/${label}_B.log"
printf '@H%s\n' "$hex" >&3
sleep 0.6
printf '@K130\n' >&3
sleep 1.5
printf 'z' >&3
end=$((SECONDS + W - 3))
while [ "$SECONDS" -lt "$end" ]; do
  if IFS= read -r -t 1 -u 3 l; then printf '%s\n' "${l%$'\r'}" >> "$EV/${label}_B.log"; fi
done
exec 3<&- 3>&-
wait
timeout 8 bash "$SC/send_read.sh" /dev/ttyS8 $'@D\n' 2 2>/dev/null >> "$EV/${label}_A.log"
for b in B C A; do
  grep -hE "PAYLOAD|INJECT|V0B_T8|ARRIVED|DROP|MB_GW|MB_DEV" "$EV/${label}_$b.log" | cut -d'|' -f2,4,5 | cut -c1-230
done
