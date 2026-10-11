#!/usr/bin/env bash
# run_reads.sh — the 5 modbus_read harnesses, then two negative controls.
#
# Writes only under $HOME, and both paths are guarded: an empty variable in an inline
# `wsl.exe -- bash -lc` string once made rsync --delete wipe a working tree, so every
# destructive path in this repo's scripts is checked before use.
set -u
source "$HOME/.cargo/env"
D="$HOME/oasis-kani"
OUT="$HOME/kani-reads"
REF="${1:?usage: run_reads.sh <git-ref>}"
case "$D"   in "$HOME"/*) ;; *) echo "refus: D hors HOME"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refus: OUT hors HOME"; exit 3;; esac
rm -rf "$OUT"; mkdir -p "$OUT/neg"
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  $(cargo kani --version | head -1)"

H="proof_omq1_parse_is_total \
proof_omv1_parse_is_total_and_count_matches_length \
proof_no_read_frame_without_ok \
proof_read_frame_is_exactly_the_query \
proof_parse_tcp_read_never_accepts_a_write"

cd "$D/oasis-rt"
run() { # run <dir> <log> <harness>
  set +e
  cargo kani --lib --harness "$3" --exact -Z unstable-options -Z stubbing \
    --harness-timeout 900s --output-format terse > "$1/$2" 2>&1
  set -e
  # "FAILED" has two meanings and they are not interchangeable: a property named after
  # `Failed Checks:` is a refutation, an `unwinding assertion loop N` is inconclusive.
  if grep -qE "^VERIFICATION:- SUCCESSFUL" "$1/$2"; then echo "  SUCCESSFUL   $3"
  elif grep -qE "^VERIFICATION:- FAILED" "$1/$2"; then
    if grep -q "unwinding assertion" "$1/$2"; then echo "  UNWIND(indetermine) $3"
    else echo "  FAILED       $3"; fi
  else echo "  UNDETERMINED $3"; fi
}

echo "== arbre tel quel : les 5 doivent passer =="
for h in $H; do run "$OUT" "$h.log" "modbus_read::kani_proofs::$h"; done

echo "== controle negatif A : le span n'est verifie que sur son premier registre =="
python3 - "$D" <<'PY'
import io, sys, os
p = os.path.join(sys.argv[1], 'oasis-rt/src/modbus_read/mod.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old = '    let mut i = 0u8;\n    while i < count {'
new = '    let mut i = 0u8;\n    while i < 1 {'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant A: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant A applique: span_allowed ne verifie plus que le premier registre')
PY
run "$OUT/neg" "A_no_read_frame_without_ok.log" modbus_read::kani_proofs::proof_no_read_frame_without_ok
git -C "$D" checkout -- oasis-rt/src/modbus_read/mod.rs

echo "== controle negatif B : parse_omv1 accepte un count qui ment =="
python3 - "$D" <<'PY'
import io, sys, os
p = os.path.join(sys.argv[1], 'oasis-rt/src/modbus_read/mod.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old = 'if count == 0 || count as usize > MAX_READ_REGS || b.len() != OMV1_HEADER_LEN + 2 * count as usize {'
new = 'if count == 0 || count as usize > MAX_READ_REGS || b.len() < OMV1_HEADER_LEN {'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant B: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant B applique: la longueur declaree n est plus liee aux octets portes')
PY
run "$OUT/neg" "B_omv1_count_matches_length.log" modbus_read::kani_proofs::proof_omv1_parse_is_total_and_count_matches_length
git -C "$D" checkout -- oasis-rt/src/modbus_read/mod.rs

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP"
echo "preuves :"; grep -h "^VERIFICATION:-" "$OUT"/*.log | sort | uniq -c
echo "controles negatifs (doivent echouer) :"; grep -h "^VERIFICATION:-" "$OUT"/neg/*.log | sort | uniq -c
