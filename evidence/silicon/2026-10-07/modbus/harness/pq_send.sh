#!/usr/bin/env bash
# pq_send.sh <label> <sender:A|B|C> <hexfile|-> <final_line> <outdir>
# Stages an OAU1 message on the sender (`@C`, then `@Q<hex>` chunks of 280 bytes),
# then sends <final_line> (e.g. `F`, `T5`, `I`, or `P<hex>` for a legacy payload; `-`
# for hexfile skips staging) and captures A, B and C for W seconds (LF only).
label="$1"; sender="$2"; hexfile="$3"; final="$4"; out="$5"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
declare -A DEV=([A]=/dev/ttyS8 [B]=/dev/ttyS9 [C]=/dev/ttyS10)
W=${W:-25}
pids=()
for b in A B C; do
  [ "$b" = "$sender" ] && continue
  timeout $(( W + 3 )) bash "$SC/read_dev.sh" "${DEV[$b]}" $(( W + 1 )) > "$out/${label}_${b}.log" 2>/dev/null &
  pids+=($!)
done
dev="${DEV[$sender]}"
stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null
exec 3<>"$dev"
: > "$out/${label}_${sender}.log"
if [ "$hexfile" != "-" ]; then
  hex=$(tr -d ' \r\n' < "$hexfile")
  printf '@C\n' >&3
  for (( i=0; i<${#hex}; i+=560 )); do
    printf '@Q%s\n' "${hex:i:560}" >&3
    if IFS= read -r -t 2 -u 3 line; then printf '%s\n' "${line%$'\r'}" >> "$out/${label}_${sender}.log"; fi
  done
fi
printf '@%s\n' "$final" >&3
end=$((SECONDS + W))
while [ "$SECONDS" -lt "$end" ]; do
  if IFS= read -r -t 1 -u 3 line; then printf '%s\n' "${line%$'\r'}" >> "$out/${label}_${sender}.log"; fi
done
exec 3<&- 3>&-
wait "${pids[@]}"
exit 0
