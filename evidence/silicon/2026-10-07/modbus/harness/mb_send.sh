#!/usr/bin/env bash
# mb_send.sh <label> <board:A|B|C> <line> <outdir>
# Phase 1.4: send one line (e.g. "@P<hex>", "@J<hex>", "@K40", "S", "@G", "@D") to one
# board and capture all three boards for W seconds (default 6), LF-only logs
# <outdir>/<label>_<board>.log. One process per port (Windows COM ports are exclusive).
label="$1"; board="$2"; line="$3"; out="$4"; W="${W:-6}"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
declare -A DEV=([A]=/dev/ttyS8 [B]=/dev/ttyS9 [C]=/dev/ttyS10)
pids=()
for b in A B C; do
  [ "$b" = "$board" ] && continue
  timeout $(( W + 3 )) bash "$SC/read_dev.sh" "${DEV[$b]}" $(( W + 1 )) > "$out/${label}_${b}.log" 2>/dev/null &
  pids+=($!)
done
sleep 1.5  # let the readers open their ports first (a fast reply was lost once: 11_*)
dev="${DEV[$board]}"
stty -F "$dev" 115200 raw -echo -ixon 2>/dev/null
exec 3<>"$dev"
printf '%s\n' "$line" >&3
end=$((SECONDS + W))
: > "$out/${label}_${board}.log"
while [ "$SECONDS" -lt "$end" ]; do
  if IFS= read -r -t 1 -u 3 l; then printf '%s\n' "${l%$'\r'}" >> "$out/${label}_${board}.log"; fi
done
exec 3<&- 3>&-
wait "${pids[@]}"
exit 0
