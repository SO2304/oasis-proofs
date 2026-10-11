#!/usr/bin/env bash
# fuzz_campaign.sh <seconds_per_target> <outdir>
# Phase 2.3: run the 8 oasis-rt fuzz targets (Windows, nightly-2025-11-21, ASan), 4 at a
# time, each for <seconds_per_target>. One log per target plus campaign.log (UTC start /
# end / exit code). Corpora stay in oasis-rt/fuzz/corpus/<target> (git-ignored); crash
# inputs in oasis-rt/fuzz/artifacts/<target>. Deletes nothing.
set -euo pipefail
secs="${1:?seconds per target}"
out="${2:?output directory}"
mkdir -p "$out"
ASAN_DIR="/c/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64"
[ -f "$ASAN_DIR/clang_rt.asan_dynamic-x86_64.dll" ] || { echo "ASan runtime not found"; exit 2; }
export PATH="$ASAN_DIR:$PATH"
cd /c/dev/oasis/oasis-rt
echo "[$(date -u +%FT%TZ)] campaign: ${secs}s per target, tree $(git rev-parse --short HEAD), $(cargo +nightly-2025-11-21 --version)" >> "$out/campaign.log"
run() {
  local t="$1" rc=0
  echo "[$(date -u +%FT%TZ)] start $t" >> "$out/campaign.log"
  cargo +nightly-2025-11-21 fuzz run "$t" -O -- -max_total_time="$secs" -print_final_stats=1 > "$out/$t.log" 2>&1 || rc=$?
  echo "[$(date -u +%FT%TZ)] end $t exit $rc" >> "$out/campaign.log"
}
for batch in "mesh_v0b authority modbus revocation" "actuation enrollment firmware mavlink"; do
  for t in $batch; do run "$t" & done
  wait
done
echo "[$(date -u +%FT%TZ)] campaign done" >> "$out/campaign.log"
