#!/usr/bin/env bash
# run_journal.sh <git-ref> — the 6 journal harnesses after adding the change region, then
# two negative controls on the properties that region could break.
#
# Writes only under $HOME, both paths guarded.
set -u
source "$HOME/.cargo/env"
D="$HOME/oasis-kani"
OUT="$HOME/kani-journal"
REF="${1:?usage: run_journal.sh <git-ref, a BRANCH not a short sha>}"
case "$D"   in "$HOME"/*) ;; *) echo "refus: D hors HOME"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refus: OUT hors HOME"; exit 3;; esac
rm -rf "$OUT"; mkdir -p "$OUT/neg"
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  $(cargo kani --version | head -1)"

H="proof_entry_roundtrip_is_lossless \
proof_journal_seq_monotone \
proof_journal_parse_total \
proof_decision_byte_is_injective \
proof_every_decision_is_logged \
proof_change_record_preserves_what_an_auditor_reads"

cd "$D/oasis-rt"
run() { # run <dir> <log> <harness>
  set +e
  cargo kani --lib --harness "$3" --exact -Z unstable-options -Z stubbing \
    --harness-timeout 900s --output-format terse > "$1/$2" 2>&1
  set -e
  if grep -qE "^VERIFICATION:- SUCCESSFUL" "$1/$2"; then echo "  SUCCESSFUL   $3"
  elif grep -qE "^VERIFICATION:- FAILED" "$1/$2"; then
    if grep -q "unwinding assertion" "$1/$2"; then echo "  UNWIND(indetermine) $3"
    else echo "  FAILED       $3"; fi
  else echo "  UNDETERMINED $3"; fi
}

echo "== arbre tel quel : les 6 doivent passer =="
for h in $H; do run "$OUT" "$h.log" "journal::kani_proofs::$h"; done

echo "== controle negatif A : la region des changements chevauche celle des refus =="
python3 - "$D" <<'PY'
import io, sys, os
p = os.path.join(sys.argv[1], 'oasis-rt/src/journal.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old = 'pub const DEC_CHANGE_BASE: u8 = 64;'
new = 'pub const DEC_CHANGE_BASE: u8 = 20;'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant A: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant A applique: DEC_CHANGE_BASE 64 -> 20, un refus lirait comme un changement')
PY
run "$OUT/neg" "A_decision_byte_is_injective.log" journal::kani_proofs::proof_decision_byte_is_injective
git -C "$D" checkout -- oasis-rt/src/journal.rs

echo "== controle negatif B : le drapeau applique/refuse est perdu =="
python3 - "$D" <<'PY'
import io, sys, os
p = os.path.join(sys.argv[1], 'oasis-rt/src/journal.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old = '            if applied { FLAG_CHANGE_APPLIED } else { 0 },'
new = '            FLAG_CHANGE_APPLIED,'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant B: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant B applique: un changement refuse est enregistre comme applique')
PY
run "$OUT/neg" "B_change_record_preserves.log" journal::kani_proofs::proof_change_record_preserves_what_an_auditor_reads
git -C "$D" checkout -- oasis-rt/src/journal.rs

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP"
echo "preuves :"; grep -h "^VERIFICATION:-" "$OUT"/*.log | sort | uniq -c
echo "controles negatifs (doivent echouer) :"; grep -h "^VERIFICATION:-" "$OUT"/neg/*.log | sort | uniq -c
