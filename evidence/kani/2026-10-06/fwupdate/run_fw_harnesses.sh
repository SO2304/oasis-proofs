#!/usr/bin/env bash
# Kani run of the 3 harnesses added with Phase 1.3 (oasis-rt/src/firmware.rs).
# Usage (inside WSL): run_fw_harnesses.sh <commit>. Same procedure as ../enroll/.
set -u
source "$HOME/.cargo/env" 2>/dev/null
REV="${1:?commit}"
echo "[$(date -u +%FT%TZ)] host: $(uname -r), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(cargo kani --version 2>&1 | head -1)"
D="$HOME/oasis-kani"
git -C "$D" fetch -q /mnt/c/dev/oasis oasis-vs-veridify && git -C "$D" checkout -q -f "$REV" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD)"
cd "$D/oasis-rt" || exit 3
H=""
for h in proof_fw_install_requires_all_conditions proof_fw_floor_never_lowers proof_fw_parsers_total; do
  H="$H --harness $h"
done
echo "[$(date -u +%FT%TZ)] cargo kani --lib$H"
cargo kani --lib $H -Z unstable-options -Z stubbing --harness-timeout 600s --output-format terse 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] cargo kani exit code $rc"
