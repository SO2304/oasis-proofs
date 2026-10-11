#!/usr/bin/env bash
# Kani run of the harnesses added with Phase 1.2 (6 in run 1, 7 from run 2) (enrollment.rs, ownership.rs).
# Usage (inside WSL): run_enroll_harnesses.sh <commit>. Same procedure as ../pq/.
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
  proof_enr_revoked_never_enrolled proof_enr_seq_never_decreases proof_enr_other_entries_untouched proof_enr_parse_total \
  proof_own_transfer_requires_both_signatures proof_own_offer_rules proof_own_accept_parse_total; do
  H="$H --harness $h"
done
echo "[$(date -u +%FT%TZ)] cargo kani --lib$H"
cargo kani --lib $H -Z unstable-options -Z stubbing --harness-timeout 600s --output-format terse 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] cargo kani exit code $rc"
