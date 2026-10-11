#!/usr/bin/env bash
# run_jk_harnesses.sh — verify the 7 new phase-2 harnesses (parts J and K) on a clean git
# clone of the committed state. Writes nothing outside $D and $OUT. No rsync, no --delete.
set -euo pipefail
source "$HOME/.cargo/env"

D="$HOME/oasis-kani"
OUT="$HOME/kani-jk"
REF="${1:?usage: run_jk_harnesses.sh <git-ref>}"
case "$D" in "$HOME"/*) ;; *) echo "refusing: D=$D"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refusing: OUT=$OUT"; exit 3;; esac
[ -d "$D/.git" ] || { echo "no clone at $D"; exit 3; }
rm -rf "$OUT"; mkdir -p "$OUT"

git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] ref=$REF stamp=$STAMP, $(cargo kani --version | head -1)"

HARNESSES="
proof_oas1_parse_total
proof_oas1_equivalent_to_oac1_stop
proof_oas1_addressing_is_total
proof_timeview_stamp_total
proof_timeview_window_is_bounded
proof_timeview_refuses_stale_and_backwards
proof_timeview_apply_is_monotone_within_a_boot
"

cd "$D/oasis-rt"
pass=0; fail=0; undet=0
for h in $HARNESSES; do
  log="$OUT/${h}.log"
  echo "=== $h ($(date -u +%TZ))"
  set +e
  cargo kani --lib --harness "$h" -Z unstable-options -Z stubbing \
    --harness-timeout 900s --output-format terse > "$log" 2>&1
  rc=$?
  set -e
  if grep -qE "^VERIFICATION:- SUCCESSFUL" "$log"; then
    echo "  SUCCESSFUL"; pass=$((pass+1))
  elif grep -qE "^VERIFICATION:- FAILED" "$log"; then
    echo "  *** FAILED (counterexample) ***"; fail=$((fail+1))
    grep -A 3 "^Failed Checks" "$log" | sed 's/^/    /' | head -6
  else
    echo "  UNDETERMINED (rc=$rc) — not a refutation"; undet=$((undet+1))
    tail -4 "$log" | sed 's/^/    /'
  fi
done

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  verified=$pass  refuted=$fail  undetermined=$undet"
