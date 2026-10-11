#!/usr/bin/env bash
# run_originmap.sh <branch> — the per-origin register-map harness, then a negative control
# whose mutation is verified applied (the script aborts otherwise, as rule 4 requires).
set -u
source "$HOME/.cargo/env"
D="$HOME/oasis-kani"
OUT="$HOME/kani-originmap"
REF="${1:?usage: run_originmap.sh <branch, not a short sha>}"
case "$D"   in "$HOME"/*) ;; *) echo "refus: D hors HOME"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refus: OUT hors HOME"; exit 3;; esac
rm -rf "$OUT"; mkdir -p "$OUT/neg"
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  $(cargo kani --version | head -1)"

H="proof_mb_no_frame_outside_the_origin_map proof_mb_no_frame_without_act proof_mb_frame_matches_rules"

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

echo "== arbre tel quel : les 3 doivent passer =="
for h in $H; do run "$OUT" "$h.log" "modbus_gateway::kani_proofs::$h"; done

echo "== controle negatif : la carte d'une origine est consultee sans filtrer l'origine =="
python3 - "$D" <<'PY'
import io, os, sys
p = os.path.join(sys.argv[1], 'oasis-rt/src/modbus_gateway.rs')
s = io.open(p, encoding='utf-8', newline='').read()
# Drop the origin filter from the per-origin lookup: any origin's rule would then allow
# any other origin's register, which is exactly the property under test.
old = 'if &e.origin == origin && e.rule.addr == addr {'
new = 'if e.rule.addr == addr {'
n = s.count(old)
if n != 1:
    raise SystemExit('ABORT mutant: motif trouve %d fois' % n)
io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new))
print('  mutant applique: le filtre par origine est retire du parcours de la carte')
PY
run "$OUT/neg" "A_origin_filter_removed.log" modbus_gateway::kani_proofs::proof_mb_no_frame_outside_the_origin_map
git -C "$D" checkout -- oasis-rt/src/modbus_gateway.rs

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP"
echo "preuves :"; grep -h "^VERIFICATION:-" "$OUT"/*.log | sort | uniq -c
echo "controle negatif (doit echouer) :"; grep -h "^VERIFICATION:-" "$OUT"/neg/*.log | sort | uniq -c
