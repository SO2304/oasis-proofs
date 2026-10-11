#!/usr/bin/env bash
# run_sealed.sh — the 4 OSE1 harnesses, then two negative controls. Writes only in $HOME.
set -u
source "$HOME/.cargo/env"
D="$HOME/oasis-kani"
OUT="$HOME/kani-sealed"
REF="${1:?usage: run_sealed.sh <git-ref>}"
case "$D"   in "$HOME"/*) ;; *) echo refus; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo refus; exit 3;; esac
rm -rf "$OUT"; mkdir -p "$OUT/neg"
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  $(cargo kani --version | head -1)"

H="proof_sealed_dest_total proof_sealed_dest_accepts_a_wellformed_blob proof_ose1_len_is_sane proof_nonce_is_injective_in_the_counter proof_open_refuses_another_destination_without_crypto"

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

echo "== arbre tel quel : les 4 doivent passer =="
for h in $H; do run "$OUT" "$h.log" "sealed::kani_proofs::$h"; done

echo "== controle negatif A : sealed_dest accepte un blob trop court =="
python3 - "$D" <<'PY'
import io, sys, os
p = os.path.join(sys.argv[1], 'oasis-rt/src/sealed.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old = 'if blob.len() < ose1_len(0) || blob[0..4] != OSE1_MAGIC {'
new = 'if blob.len() < 4 || blob[0..4] != OSE1_MAGIC {'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant A: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant A applique: la borne de longueur tombe a 4')
PY
run "$OUT/neg" "A_sealed_dest_total.log" sealed::kani_proofs::proof_sealed_dest_total
git -C "$D" checkout -- oasis-rt/src/sealed.rs

echo "== controle negatif B : le nonce ignore les 4 octets hauts du compteur =="
python3 - "$D" <<'PY'
import io, sys, os
p = os.path.join(sys.argv[1], 'oasis-rt/src/sealed.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old = 'n[..8].copy_from_slice(&counter.to_le_bytes());'
new = 'n[..4].copy_from_slice(&(counter as u32).to_le_bytes());'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant B: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant B applique: deux compteurs peuvent partager un nonce')
PY
run "$OUT/neg" "B_nonce_injective.log" sealed::kani_proofs::proof_nonce_is_injective_in_the_counter
git -C "$D" checkout -- oasis-rt/src/sealed.rs

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP"
echo "preuves :"; grep -h "^VERIFICATION:-" "$OUT"/*.log | sort | uniq -c
echo "controles negatifs (doivent echouer) :"; grep -h "^VERIFICATION:-" "$OUT"/neg/*.log | sort | uniq -c
