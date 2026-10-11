#!/usr/bin/env bash
# Run 3: the 6 Phase 1.1 harnesses plus proof_frag_reassembler_never_panics, which
# stubs SHA-256 (#[kani::stub]) and therefore needs -Z stubbing. Same procedure as
# run_pq_harnesses.sh (kept unchanged for runs 1-2). Usage (WSL): <script> <commit>.
set -u
source "$HOME/.cargo/env" 2>/dev/null
REV="${1:?commit}"
echo "[$(date -u +%FT%TZ)] host: $(uname -r), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(cargo kani --version 2>&1 | head -1)"
D="$HOME/oasis-kani"
git -C "$D" fetch -q /mnt/c/dev/oasis oasis-vs-veridify && git -C "$D" checkout -q -f "$REV" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD)"
cd "$D/oasis-rt" || exit 3
H=""
for h in \
  proof_auth_hybrid_requires_both proof_auth_policy_never_lowers proof_auth_parse_total \
  proof_auth_precheck_no_downgrade proof_frag_parse_in_bounds proof_frag_completion_mask \
  proof_frag_reassembler_never_panics; do
  H="$H --harness $h"
done
echo "[$(date -u +%FT%TZ)] cargo kani --lib$H -Z stubbing"
cargo kani --lib $H -Z unstable-options -Z stubbing --harness-timeout 600s --output-format terse 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] cargo kani exit code $rc"
