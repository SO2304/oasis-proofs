#!/usr/bin/env bash
# pf_run.sh <mode:v0b|v0c> <rate> <secs> <label>
# Phase 2.1 measurement. C = relay under test (terminal), B = injector + legitimate origin.
#
# IMPORTANT: one command per write, with a gap. The firmware keeps a SINGLE line buffer
# per USB read, so two commands in one write silently lose the first (this invalidated the
# runs before 2026-10-07T10:50Z: B stayed in v0B while C expected v0C). Each run now
# verifies the mode actually took on BOTH boards and aborts if not.
set -u
mode="$1"; rate="$2"; secs="$3"; label="$4"
SC=/c/Users/pc/AppData/Local/Temp/claude/c--dev-oasis/3b644d8a-d030-4382-a054-af7fa383b4ab/scratchpad
EV=/c/dev/oasis/evidence/silicon/2026-10-07/prefilter
C_FP=a7089677a10b7fb0
if [ "$mode" = "v0c" ]; then c_cmd='@O1'; b_cmd="@O1${C_FP}"; want='v0c=true'; else c_cmd='@O0'; b_cmd='@O0'; want='v0c=false'; fi

send() { timeout 10 bash "$SC/send_read.sh" "$1" "$2"$'\n' 2 2>/dev/null; }

: > "$EV/${label}_C.log"; : > "$EV/${label}_B.log"
# 1. mode (resets the counters), then quiet — separate writes
send /dev/ttyS10 "$c_cmd" >> "$EV/${label}_C.log"
send /dev/ttyS10 '@S1'    >> "$EV/${label}_C.log"
send /dev/ttyS9  "$b_cmd" >> "$EV/${label}_B.log"
send /dev/ttyS9  '@S1'    >> "$EV/${label}_B.log"

# 2. both boards must confirm the mode, or the run is void
for pair in "C:$EV/${label}_C.log" "B:$EV/${label}_B.log"; do
  who=${pair%%:*}; f=${pair#*:}
  if ! grep -q "PF_MODE|$want" "$f"; then
    echo "ABORT $label: $who did not confirm $want"
    grep -h PF_MODE "$f" | cut -d'|' -f4,5 || echo "  (no PF_MODE at all)"
    exit 2
  fi
done

# 3. the flood (blocks B for secs + the pre-signing; C stays quiet)
echo "# flood mode=$mode rate=$rate secs=$secs start=$(date -u +%FT%TZ)" >> "$EV/${label}_B.log"
timeout $(( secs + 90 )) bash "$SC/send_read.sh" /dev/ttyS9 "@Y${rate},${secs},${LEGIT:-1}"$'\n' $(( secs + 70 )) 2>/dev/null >> "$EV/${label}_B.log"

# 4. the injector must have run in the expected mode too
grep -q "PF_FLOOD|start,rate=$rate,secs=$secs,$want" "$EV/${label}_B.log" || { echo "ABORT $label: injector ran in the wrong mode"; grep -h PF_FLOOD "$EV/${label}_B.log" | cut -d'|' -f4,5; exit 3; }

# 5. read the relay's counters, then leave quiet mode
send /dev/ttyS10 '@B'  >> "$EV/${label}_C.log"
send /dev/ttyS10 '@S0' >> "$EV/${label}_C.log"

grep -hE "PF_MODE|PF_PRESIGN|PF_FLOOD|PF_STATUS" "$EV/${label}_B.log" "$EV/${label}_C.log" | cut -d'|' -f2,4,5
