#!/usr/bin/env bash
# Negative control for B1: three mutations, three named proofs must FAIL.
# Operates on $HOME/oasis-kani-neg, a throwaway clone. Deletes nothing else.
set -euo pipefail
source "$HOME/.cargo/env"

D="$HOME/oasis-kani-neg"
OUT="$HOME/kani-b1-neg"
REF="${1:?usage: run_neg_b1.sh <git-ref>}"
case "$D" in "$HOME"/*) ;; *) echo "refusing: D=$D"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refusing: OUT=$OUT"; exit 3;; esac

rm -rf "$D" "$OUT"
git clone -q "$HOME/oasis-kani" "$D"
git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
STAMP="$(git -C "$D" rev-parse --short HEAD)"
mkdir -p "$OUT"
echo "[$(date -u +%FT%TZ)] negative control on $STAMP"

python3 "$HOME/kani_neg_b1.py" "$D" apply

cd "$D/oasis-rt"
rc_all=0
for h in proof_stop_class_never_arms proof_no_arm_frame_without_act proof_action_is_total_and_binary; do
  log="$OUT/${h}.log"
  set +e
  cargo kani --lib --harness "$h" -Z unstable-options -Z stubbing \
    --harness-timeout 900s --output-format terse > "$log" 2>&1
  set -e
  if grep -qE "^VERIFICATION:- FAILED" "$log"; then
    echo "  $h: FAILED as intended"
  elif grep -qE "^VERIFICATION:- SUCCESSFUL" "$log"; then
    echo "  *** $h: STILL SUCCESSFUL — the control is invalid, the proof does not bind ***"
    rc_all=1
  else
    echo "  *** $h: undetermined — control inconclusive ***"
    rc_all=1
  fi
done
echo "[$(date -u +%FT%TZ)] negative control done, rc=$rc_all"
exit $rc_all
