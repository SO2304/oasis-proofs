#!/usr/bin/env bash
# fuzz_batch2.sh <seconds_per_target> <outdir>
# Phase 2.3, batch 2: the 4 targets that never ran (actuation, enrollment, firmware,
# mavlink), 4 in parallel. Batch 1 completed 2026-10-07 (DONE, ~524 M execs, 0 crashes).
# Corpora persist in oasis-rt/fuzz/corpus/<target>; crash inputs in fuzz/artifacts/.
# Deletes nothing.
set -euo pipefail
secs="${1:?seconds per target}"
out="${2:?output directory}"
[ -n "$out" ] && [ "$out" != "/" ] || { echo "refusing an empty or root outdir"; exit 2; }
mkdir -p "$out"
ASAN_DIR="/c/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64"
[ -f "$ASAN_DIR/clang_rt.asan_dynamic-x86_64.dll" ] || { echo "ASan runtime not found"; exit 3; }
export PATH="$ASAN_DIR:$PATH"
cd /c/dev/oasis/oasis-rt
echo "[$(date -u +%FT%TZ)] batch 2: ${secs}s per target, tree $(git rev-parse --short HEAD)" >> "$out/campaign.log"
run() {
  local t="$1" rc=0
  echo "[$(date -u +%FT%TZ)] start $t" >> "$out/campaign.log"
  cargo +nightly-2025-11-21 fuzz run "$t" -O -- -max_total_time="$secs" -print_final_stats=1 > "$out/$t.log" 2>&1 || rc=$?
  echo "[$(date -u +%FT%TZ)] end $t exit $rc" >> "$out/campaign.log"
}
for t in actuation enrollment firmware mavlink; do run "$t" & done
wait
echo "[$(date -u +%FT%TZ)] batch 2 done" >> "$out/campaign.log"
