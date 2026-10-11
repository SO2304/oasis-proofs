#!/usr/bin/env bash
# run_hardening_harnesses.sh — verify the 14 new phase-2 harnesses (parts G, H, I) on a
# clean git clone of the committed state. Writes nothing outside $D and $OUT.
# No rsync, no --delete: a git checkout only (lesson of 2026-10-07).
set -euo pipefail
source "$HOME/.cargo/env"

D="$HOME/oasis-kani"
OUT="$HOME/kani-hardening"
REF="${1:?usage: run_hardening_harnesses.sh <git-ref>}"

# Path guards: both must be non-empty, absolute, and under $HOME.
case "$D" in "$HOME"/*) ;; *) echo "refusing: D=$D not under HOME"; exit 3;; esac
case "$OUT" in "$HOME"/*) ;; *) echo "refusing: OUT=$OUT not under HOME"; exit 3;; esac
[ -d "$D/.git" ] || { echo "no clone at $D"; exit 3; }
mkdir -p "$OUT"

git -C "$D" fetch -q /mnt/c/dev/oasis "$REF"
git -C "$D" checkout -q --detach FETCH_HEAD
git -C "$D" clean -qfd -e target
STAMP="$(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] ref=$REF stamp=$STAMP"
echo "[$(date -u +%FT%TZ)] $(cargo kani --version | head -1), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(nproc) cores"

HARNESSES="
proof_stop_never_blocked
proof_stop_requires_authenticity
proof_act_refused_while_stopped
proof_act_rule_unchanged
proof_act_needs_live_supervision
proof_stop_ignores_supervision
proof_supervision_bounded
proof_osb1_parse_total
proof_order_class_total
proof_entry_roundtrip_is_lossless
proof_journal_seq_monotone
proof_journal_parse_total
proof_decision_byte_is_injective
proof_every_decision_is_logged
"

cd "$D/oasis-rt"
pass=0; fail=0; undet=0
for h in $HARNESSES; do
  log="$OUT/${h}.log"
  echo "=== $h ($(date -u +%TZ))"
  set +e
  cargo kani --lib --harness "$h" \
    -Z unstable-options -Z stubbing \
    --harness-timeout 900s --output-format terse \
    > "$log" 2>&1
  rc=$?
  set -e
  if grep -qE "^VERIFICATION:- SUCCESSFUL" "$log"; then
    echo "  SUCCESSFUL"; pass=$((pass+1))
  elif grep -qE "^VERIFICATION:- FAILED" "$log"; then
    echo "  *** FAILED (counterexample) ***"; fail=$((fail+1))
  else
    echo "  UNDETERMINED (rc=$rc) — not a refutation; see $log"; undet=$((undet+1))
    tail -5 "$log" | sed 's/^/    /'
  fi
done

echo
echo "[$(date -u +%FT%TZ)] stamp=$STAMP  verified=$pass  refuted=$fail  undetermined=$undet"
