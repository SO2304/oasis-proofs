#!/usr/bin/env bash
# Modbus TCP Kani harnesses + negative controls. Run from the repository root on a clean tree.
#   evidence/kani/2026-10-07/modbus_tcp/run_mbtcp.sh <out_dir>
# 1. both harnesses on the tree as committed (expected: verified);
# 2. mutant A (MBAP tid altered in from_rtu) -> proof_mbtcp_frame_iff_act_and_matches_order must FAIL;
# 3. mutant B (FC16 quantity 9 accepted)     -> proof_mbtcp_parse_total must FAIL.
# Each mutation must apply, or the script aborts (a control that ran unmutated proves nothing).
set -uo pipefail
out=${1:?out_dir}; mkdir -p "$out"
src=oasis-rt/src/modbus_tcp.rs
git diff --quiet -- "$src" || { echo "modified $src: run on a clean tree"; exit 2; }
trap 'git checkout -- "$src"' EXIT
k() { (cd oasis-rt && cargo kani --lib --harness "modbus_tcp::kani_proofs::$1" --exact -Z unstable-options -Z stubbing -j 1); }
{ git rev-parse HEAD; cargo kani --version; } > "$out/kani_mbtcp_env.txt" 2>&1
for h in proof_mbtcp_frame_iff_act_and_matches_order proof_mbtcp_parse_total; do
  k "$h" > "$out/kani_mbtcp_${h}.log" 2>&1; echo "$h exit $?"
done
mutate() { # $1 = sed expression, $2 = harness, $3 = log name
  git checkout -- "$src"; sed -i "$1" "$src"
  git diff --quiet -- "$src" && { echo "mutation for $2 did not apply: abort"; exit 3; }
  k "$2" > "$out/$3" 2>&1; echo "$3 exit $? (expected non-zero)"
}
mutate 's/mbap(&mut b, tid, rtu.bytes\[0\], pdu.len());/mbap(\&mut b, tid ^ 1, rtu.bytes[0], pdu.len());/' proof_mbtcp_frame_iff_act_and_matches_order kani_mbtcp_negative_control_A_tid.log
mutate 's/if qty == 0 || qty > MAX_REGS ||/if qty == 0 || qty > MAX_REGS + 1 ||/' proof_mbtcp_parse_total kani_mbtcp_negative_control_B_qty9.log
