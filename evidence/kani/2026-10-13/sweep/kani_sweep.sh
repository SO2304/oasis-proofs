#!/usr/bin/env bash
# kani_sweep.sh — the first attempt at the whole suite on this machine: every harness that
# is NOT declared heavy, run ONE AT A TIME (the parallel full run of 2026-10-07 was
# OOM-killed at 130/152 on these 3.3 GB). The 7 heavy ones are skipped on purpose: the
# shard script gives them 60 min each alone, which belongs on CI.
#
# Writes only inside $HOME/oasis-kani and $HOME/kani-sweep.
set -u
source "$HOME/.cargo/env"

D="$HOME/oasis-kani"
OUT="$HOME/kani-sweep"
REF="${1:?usage: kani_sweep.sh <git-ref>}"
PER_TIMEOUT="${2:-300}"
case "$D"   in "$HOME"/*) ;; *) echo "refus: D=$D";   exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refus: OUT=$OUT"; exit 3;; esac
[ -d "$D/.git" ] || { echo "pas de clone a $D"; exit 3; }

rm -rf "$OUT"; mkdir -p "$OUT/logs"
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"

cd "$D/oasis-rt"
bash kani_shards.sh --all > "$OUT/assignment.txt" 2>/dev/null
TOTAL=$(wc -l < "$OUT/assignment.txt")
grep -v '^heavy-' "$OUT/assignment.txt" | awk '{print $2}' > "$OUT/todo.txt"
N=$(wc -l < "$OUT/todo.txt")
HEAVY=$((TOTAL - N))

echo "[$(date -u +%FT%TZ)] stamp=$STAMP  total=$TOTAL  a_balayer=$N  lourds_ignores=$HEAVY"
echo "kani: $(cargo kani --version 2>&1 | head -1)"
echo

ok=0; bad=0; undet=0; i=0
: > "$OUT/results.tsv"
while read -r h; do
  i=$((i+1))
  log="$OUT/logs/${h//:/_}.log"
  set +e
  timeout "$((PER_TIMEOUT + 60))" cargo kani --lib --harness "$h" --exact \
    -Z unstable-options -Z stubbing --harness-timeout "${PER_TIMEOUT}s" \
    --output-format terse > "$log" 2>&1
  rc=$?
  set -e
  if grep -qE "^VERIFICATION:- SUCCESSFUL" "$log"; then
    v=VERIFIED; ok=$((ok+1))
  elif grep -qE "^VERIFICATION:- FAILED" "$log"; then
    if grep -q "unwinding assertion" "$log"; then
      v=UNDETERMINED_UNWIND; undet=$((undet+1))
    else
      v=REFUTED; bad=$((bad+1))
    fi
  else
    v=UNDETERMINED; undet=$((undet+1))
  fi
  printf '%s\t%s\t%s\n' "$v" "$rc" "$h" >> "$OUT/results.tsv"
  printf '[%3d/%3d] %-22s %s\n' "$i" "$N" "$v" "$h"
done < "$OUT/todo.txt"

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  verifies=$ok  refutes=$bad  indetermines=$undet  (sur $N, +$HEAVY lourds non tentes)"
echo "--- refutations, s il y en a ---"
grep -c '^REFUTED' "$OUT/results.tsv" 2>/dev/null || true
grep '^REFUTED' "$OUT/results.tsv" 2>/dev/null | cut -f3 || echo "(aucune)"
