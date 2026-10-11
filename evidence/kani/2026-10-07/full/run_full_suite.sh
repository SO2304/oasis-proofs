#!/usr/bin/env bash
# Phase 2.2: the FULL Kani suite (every #[kani::proof] in oasis-rt), not just the new
# harnesses. Usage (inside WSL): run_full_suite.sh <commit>.
# -j1 because this host has 3.3 GB: -j>1 has OOM-killed the run after a few dozen
# harnesses before (see the project memory note on the WSL limit).
set -u
source "$HOME/.cargo/env" 2>/dev/null
REV="${1:?commit}"
echo "[$(date -u +%FT%TZ)] host: $(uname -r), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(nproc) cores, $(cargo kani --version 2>&1|head -1)"
D="$HOME/oasis-kani"
git -C "$D" fetch -q /mnt/c/dev/oasis oasis-vs-veridify && git -C "$D" checkout -q -f "$REV" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD)"
echo "[$(date -u +%FT%TZ)] harnesses in tree: $(grep -rE 'kani::proof' "$D/oasis-rt/src" | wc -l)"
cd "$D/oasis-rt" || exit 3
cargo kani --lib -Z unstable-options -Z stubbing --harness-timeout 600s -j 1 --output-format terse 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] cargo kani exit code $rc"
