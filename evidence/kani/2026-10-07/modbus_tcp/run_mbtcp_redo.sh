#!/usr/bin/env bash
# run_mbtcp_redo.sh — re-run the two Modbus TCP harnesses and their two negative controls
# on the merged HEAD. The committed package listed four logs that were never committed
# (*.log is gitignored), so the evidence claimed a result it could not show.
set -u
source "$HOME/.cargo/env"
D="$HOME/oasis-kani"
OUT="$HOME/kani-mbtcp"
REF="${1:?usage: run_mbtcp_redo.sh <git-ref>}"
case "$D"   in "$HOME"/*) ;; *) echo "refus"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refus"; exit 3;; esac
[ -d "$D/.git" ] || { echo "pas de clone"; exit 3; }
rm -rf "$OUT"; mkdir -p "$OUT"

git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  $(cargo kani --version | head -1)"

cd "$D/oasis-rt"
run() { # run <log> <harness>
  set +e
  cargo kani --lib --harness "$2" --exact -Z unstable-options -Z stubbing \
    --harness-timeout 600s --output-format terse > "$OUT/$1" 2>&1
  set -e
  if grep -qE "^VERIFICATION:- SUCCESSFUL" "$OUT/$1"; then echo "  SUCCESSFUL  $2"
  elif grep -qE "^VERIFICATION:- FAILED" "$OUT/$1"; then echo "  FAILED      $2"
  else echo "  UNDETERMINED $2"; fi
}

echo "== arbre tel quel : les deux preuves doivent passer =="
run kani_mbtcp_proof_mbtcp_frame_iff_act_and_matches_order.log \
    modbus_tcp::kani_proofs::proof_mbtcp_frame_iff_act_and_matches_order
run kani_mbtcp_proof_mbtcp_parse_total.log \
    modbus_tcp::kani_proofs::proof_mbtcp_parse_total

echo "== controle negatif A : MBAP tid ^ 1 dans from_rtu =="
python3 - "$D" apply_a <<'PY'
import io, sys, os
root, mode = sys.argv[1], sys.argv[2]
p = os.path.join(root, 'oasis-rt/src/modbus_tcp.rs')
s = io.open(p, encoding='utf-8', newline='').read()
old, new = 'b[0..2].copy_from_slice(&tid.to_be_bytes());', 'b[0..2].copy_from_slice(&(tid ^ 1).to_be_bytes());'
a, b = (old, new) if mode.startswith('apply') else (new, old)
n = s.count(a)
if n != 1:
    raise SystemExit('ABORT mutant A: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(a, b))
print('  mutant A applique')
PY
run kani_mbtcp_negative_control_A_tid.log \
    modbus_tcp::kani_proofs::proof_mbtcp_frame_iff_act_and_matches_order
git -C "$D" checkout -- oasis-rt/src/modbus_tcp.rs

echo "== controle negatif B : FC16 quantite 9 acceptee =="
python3 - "$D" apply_b <<'PY'
import io, sys, os
root = sys.argv[1]
p = os.path.join(root, 'oasis-rt/src/modbus_tcp.rs')
s = io.open(p, encoding='utf-8', newline='').read()
# Widen whatever bound caps the FC16 register quantity.
old = 'if qty == 0 || qty > MAX_REGS'
new = 'if qty == 0 || qty > MAX_REGS + 1'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant B: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant B applique: la borne de quantite passe a MAX_REGS + 1')
PY
run kani_mbtcp_negative_control_B_qty9.log \
    modbus_tcp::kani_proofs::proof_mbtcp_parse_total
git -C "$D" checkout -- oasis-rt/src/modbus_tcp.rs

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP, logs dans $OUT"
grep -h "^VERIFICATION:-" "$OUT"/*.log | sort | uniq -c
