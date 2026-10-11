#!/usr/bin/env bash
# Kani run of the 3 harnesses added with Phase 2.1 (oasis-rt/src/mesh/prefilter.rs).
# Usage (inside WSL): run_pf_harnesses.sh <commit>. Same procedure as ../modbus/.
set -u
source "$HOME/.cargo/env" 2>/dev/null
REV="${1:?commit}"
echo "[$(date -u +%FT%TZ)] host: $(uname -r), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(cargo kani --version 2>&1 | head -1)"
D="$HOME/oasis-kani"
git -C "$D" fetch -q /mnt/c/dev/oasis oasis-vs-veridify && git -C "$D" checkout -q -f "$REV" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD)"
cd "$D/oasis-rt" || exit 3
H=""
for h in proof_budget_never_exceeds_burst proof_budget_refill_capped proof_v0c_parse_total; do
  H="$H --harness $h"
done
echo "[$(date -u +%FT%TZ)] cargo kani --lib$H"
cargo kani --lib $H -Z unstable-options -Z stubbing --harness-timeout 900s --output-format terse 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] cargo kani exit code $rc"
