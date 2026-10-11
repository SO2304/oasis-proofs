#!/usr/bin/env bash
# Kani run of the 6 harnesses added with Phase 1.1 (authority.rs, fragment.rs).
# Usage (inside WSL): run_pq_harnesses.sh <commit>. Fresh clone of the committed tree.
set -u
source "$HOME/.cargo/env" 2>/dev/null
REV="${1:?commit}"
echo "[$(date -u +%FT%TZ)] host: $(uname -r), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(cargo kani --version 2>&1 | head -1)"
D="$HOME/oasis-kani"
if [ -d "$D/.git" ]; then
  git -C "$D" fetch -q /mnt/c/dev/oasis oasis-vs-veridify && git -C "$D" checkout -q -f "$REV"
else
  git clone -q --branch oasis-vs-veridify /mnt/c/dev/oasis "$D" && git -C "$D" checkout -q -f "$REV"
fi
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD)"
cd "$D/oasis-rt" || exit 3
H=""
for h in \
  proof_auth_hybrid_requires_both proof_auth_policy_never_lowers proof_auth_parse_total \
  proof_auth_precheck_no_downgrade proof_frag_parse_in_bounds proof_frag_completion_mask; do
  H="$H --harness $h"
done
echo "[$(date -u +%FT%TZ)] cargo kani --lib$H"
cargo kani --lib $H -Z unstable-options --harness-timeout 300s --output-format terse 2>&1
# Capture $? first: inside the echo, $(date) would reset it (the 2026-10-06 E/F
# runner logged "exit code 0" even for a failed run because of that).
rc=$?
echo "[$(date -u +%FT%TZ)] cargo kani exit code $rc"
