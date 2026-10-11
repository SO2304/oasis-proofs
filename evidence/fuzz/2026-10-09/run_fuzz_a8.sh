#!/usr/bin/env bash
# run_fuzz_a8.sh — fuzz the parsers that had no target before 2026-10-09 (pilot A.8).
#
# Run from the repo root. Same toolchain as the 2026-10-07 and 2026-10-08 campaigns, so
# the numbers are comparable:
#
#   bash evidence/fuzz/2026-10-09/run_fuzz_a8.sh [seconds]
#
# Without the ASan runtime on PATH the binaries exit STATUS_DLL_NOT_FOUND and libFuzzer
# reports nothing, which looks like a clean run. That trap cost the 2026-10-07 campaign a
# round, so the check is first and fatal.
set -u

SECS="${1:-240}"
HERE="evidence/fuzz/2026-10-09"
[ -d "$HERE" ] || { echo "refus: lance-moi depuis la racine du depot"; exit 3; }

ASAN_DIR="/c/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64"
[ -f "$ASAN_DIR/clang_rt.asan_dynamic-x86_64.dll" ] || { echo "ASan runtime absent de $ASAN_DIR"; exit 2; }
export PATH="$ASAN_DIR:$PATH"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "refus: l'arbre n'est pas propre. Regle 5 : commiter d'abord, mesurer ensuite."
  exit 3
fi
STAMP="$(git rev-parse --short HEAD)"
echo "tree=$STAMP  $(date -u +%FT%TZ)  $(cargo +nightly-2025-11-21 fuzz --version 2>&1 | head -1)"
echo

ROOT="$PWD"
for t in modbus_tcp link_frames; do
  echo "== $t, ${SECS}s =="
  LOG="$ROOT/$HERE/$t.log"
  ( cd oasis-rt && cargo +nightly-2025-11-21 fuzz run "$t" -O -- \
      -max_total_time="$SECS" -print_final_stats=1 ) > "$LOG" 2>&1
  rc=$?
  # The first version of this script wrote its log outside the repo and then reported
  # "0 plantage" for a run that never happened: `grep -q` on a missing file returns
  # non-zero, which took the else branch. A verdict must never be reachable without the
  # evidence it is a verdict about.
  [ -s "$LOG" ] || { echo "ABANDON: $LOG vide ou absent — rien n'a tourne"; exit 4; }
  grep -q 'Done .* runs' "$LOG" || grep -qE '#[0-9]+[[:space:]]+DONE' "$LOG" || {
    echo "ABANDON: $t n'a pas termine une campagne (ni 'Done ... runs' ni '#N DONE')"
    sed -n '1,12p' "$LOG"
    exit 4
  }
  printf 'exit=%s  ' "$rc"
  grep -oE 'stat::number_of_executed_units: *[0-9]+' "$LOG" | tail -1 | tr '\n' ' '
  grep -oE 'Done [0-9]+ runs' "$LOG" | tail -1 | tr '\n' ' '
  echo
  # A crash leaves an artifact; libFuzzer also prints the word. Judge on both.
  if grep -qE 'ERROR: libFuzzer|SUMMARY: AddressSanitizer|panicked at' "$LOG"; then
    echo "  PLANTAGE — voir $HERE/$t.log et oasis-rt/fuzz/artifacts/$t/"
  else
    echo "  0 plantage"
  fi
done

echo
echo "tree=$STAMP"
