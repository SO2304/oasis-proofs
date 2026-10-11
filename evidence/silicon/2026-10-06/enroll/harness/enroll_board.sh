#!/usr/bin/env bash
# enroll_board.sh <board:A|B|C> <owner> <role> <perms> <seq> <outdir>
# PC side of enrollment (spec 1.2 §5): fresh challenge + nonce from the OS RNG,
# `@E` on the board (first call before enrollment: the board mixes the nonce into its
# key once and reboots; then `@E` again), proof of possession verified by the tool,
# then the owner signs the attestation -> <outdir>/payloads/att_<board>.hex.
# Logs: <outdir>/<prefix>_<board>.log (board output, LF) and the tool's output.
b="$1"; owner="$2"; role="$3"; perms="$4"; seq="$5"; out="$6"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
declare -A DEV=([A]=/dev/ttyS8 [B]=/dev/ttyS9 [C]=/dev/ttyS10)
dev="${DEV[$b]}"
T() { (cd /c/dev/oasis && cargo run -q -p oasis-operator-key --example oasis_enroll -- "$@" 2>/dev/null); }
log="$out/50_enroll_${b}.log"
: > "$log"
for round in 1 2; do
  read -r ch nonce < <(T challenge)
  echo "# round $round: challenge=$ch nonce=$nonce" >> "$log"
  timeout 10 bash "$SC/send_read.sh" "$dev" "@E${ch}${nonce}"$'\n' 6 >> "$log"
  if grep -q "|REKEYED|" "$log" && [ "$round" = 1 ]; then
    echo "# board rebooting after rekey; waiting" >> "$log"
    sleep 6
    continue
  fi
  pk=$(grep "|IDENTITY|" "$log" | tail -1 | sed -E 's/.*pk=([0-9a-f]{64}).*/\1/')
  sig=$(grep "|POP|" "$log" | tail -1 | sed -E 's/.*sig=([0-9a-f]{128}).*/\1/')
  if [ ${#pk} != 64 ] || [ ${#sig} != 128 ]; then echo "# no identity/pop" >> "$log"; exit 2; fi
  echo "# tool: oasis_enroll verify-pop $pk $ch $sig" >> "$log"
  T verify-pop "$pk" "$ch" "$sig" >> "$log" || { echo "# POP FAILED: not attesting" >> "$log"; exit 3; }
  mkdir -p "$out/payloads"
  T attest "$owner" "$pk" "$role" "$perms" "$seq" > "$out/payloads/att_${b}_${owner}_s${seq}.hex"
  echo "# attestation: owner=$owner role=$role perms=$perms seq=$seq bytes=$(( $(tr -d '\n' < "$out/payloads/att_${b}_${owner}_s${seq}.hex" | wc -c) / 2 ))" >> "$log"
  echo "$pk" > "$out/payloads/pk_${b}.hex"
  exit 0
done
exit 4
