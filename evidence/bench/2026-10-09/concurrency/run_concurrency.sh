#!/usr/bin/env bash
# run_concurrency.sh — the A.4 campaign: measure "one order at a time", then prove the
# regression test would actually catch the defect it was written for.
#
# Run from the repo root. Writes its logs next to itself. Bash and cargo only: rule 7 of
# the prompt allows no new Python in the repo, and the mutation is a `git apply` of a
# patch rather than a script that edits source.
#
#   bash evidence/bench/2026-10-09/concurrency/run_concurrency.sh
#
# The tree must be committed and clean: rule 5 says a campaign's stamp is the commit
# tested, so the script refuses to run otherwise rather than stamping a lie.
set -u

HERE="evidence/bench/2026-10-09/concurrency"
PATCHFILE="$HERE/mutant_lock_released.patch"
[ -f "$PATCHFILE" ] || { echo "refus: lance-moi depuis la racine du depot"; exit 3; }

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "refus: l'arbre n'est pas propre. Regle 5 : commiter d'abord, mesurer ensuite."
  exit 3
fi
STAMP="$(git rev-parse --short HEAD)"
echo "tree=$STAMP  $(date -u +%FT%TZ)"
echo

echo "== 1. le banc, K=10, appareil en boucle locale (pas de temps de reponse) =="
cargo run --release --quiet --bin bench_mbtcp_concurrency -- --rounds 10 --writes 10 \
  2>&1 | tee "$HERE/bench_delay0.log"
echo

echo "== 2. le meme banc, appareil a 2 ms : un automate a un cycle de scrutation =="
cargo run --release --quiet --bin bench_mbtcp_concurrency -- --rounds 10 --writes 10 --plc-delay-us 2000 \
  2>&1 | tee "$HERE/bench_delay2ms.log"
echo

echo "== 3. l'arbre tel quel : le test doit passer 3 fois sur 3 =="
: > "$HERE/test_clean.log"
for i in 1 2 3; do
  cargo test -p oasis-rt --release --test mbtcp_pilot_sockets concurrent 2>&1 \
    | grep -E 'test result:|were refused|out of order' | sed "s/^/run $i: /" | tee -a "$HERE/test_clean.log"
done
echo

echo "== 4. contre-epreuve : le defaut reinstalle, le test doit echouer 3 fois sur 3 =="
git apply "$PATCHFILE" || { echo "ABANDON: la mutation ne s'applique pas"; exit 4; }
if git diff --quiet -- oasis-rt/src/mbtcp_pilot/agent.rs; then
  echo "ABANDON: la mutation n'a rien change — une contre-epreuve qui ne mute rien ne prouve rien"
  exit 4
fi
echo "  mutation appliquee: l'agent relache son verrou avant l'aller-retour"
: > "$HERE/test_mutant.log"
for i in 1 2 3; do
  cargo test -p oasis-rt --release --test mbtcp_pilot_sockets concurrent 2>&1 \
    | grep -E 'test result:|were refused|out of order' | sed "s/^/run $i: /" | tee -a "$HERE/test_mutant.log"
done
echo
echo "== 5. le banc sous la mutation : le taux de refus, pour qu'il soit reproductible =="
# The ~0.9 % figure quoted in the spec, CLAUDE.md and section G has to come from a run
# anyone can repeat, not from a tree that no longer exists. The gateway's own decision
# record is what names the reason; the exception code alone would only say "refused".
cargo run --release --quiet --bin bench_mbtcp_concurrency -- --rounds 10 --writes 10 \
  2>&1 | tee "$HERE/bench_mutant_delay0.log"

git apply -R "$PATCHFILE"
git diff --quiet -- oasis-rt/src/mbtcp_pilot/agent.rs && echo "  mutation retiree, arbre identique"
echo

echo "== resume =="
printf 'arbre propre : %s\n' "$(grep -c 'test result: ok' "$HERE/test_clean.log") sur 3 verts"
printf 'mutant       : %s\n' "$(grep -c 'test result: FAILED' "$HERE/test_mutant.log") sur 3 rouges"
echo "tree=$STAMP"
