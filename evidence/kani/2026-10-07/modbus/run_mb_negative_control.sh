#!/usr/bin/env bash
# Negative control (evidence the harnesses can fail, not of correctness): copy the
# committed tree, break two rules in modbus_gateway.rs, run the two rule harnesses.
set -u
source "$HOME/.cargo/env" 2>/dev/null
D="$HOME/oasis-kani-neg"
rm -rf "$D"; git clone -q "$HOME/oasis-kani" "$D" && git -C "$D" checkout -q -f "${1:?commit}" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD) + mutations:"
F="$D/oasis-rt/src/modbus_gateway.rs"
# 1. a frame whenever the register rules pass, even without Act
sed -i 's/        Decision::Reject(_) => None,/        Decision::Reject(_) if rules == RuleCheck::Ok => Some(encode_request(o)),\n        Decision::Reject(_) => None,/' "$F"
# 2. the lower bound of each register range is no longer checked
#    (run 1 used a pattern for a multi-line layout; cargo fmt keeps this arm on one line,
#    so it never applied: the script now aborts unless both mutations changed the file)
sed -i 's/Some(r) if o.values\[i\] < r.min || o.values\[i\] > r.max =>/Some(r) if o.values[i] > r.max =>/' "$F"
git -C "$D" diff --stat; git -C "$D" diff | grep '^[-+] '
n=$(git -C "$D" diff | grep -c '^+ ')
[ "$n" -eq 2 ] || { echo "ABORT: expected 2 mutated lines, got $n"; exit 4; }
cd "$D/oasis-rt" || exit 3
cargo kani --lib --harness proof_mb_no_frame_without_act --harness proof_mb_frame_matches_rules -Z unstable-options -Z stubbing --harness-timeout 900s --output-format terse 2>&1 | grep -vE "^\s+(Compiling|Checking)"
echo "[$(date -u +%FT%TZ)] cargo kani exit code ${PIPESTATUS[0]}"
