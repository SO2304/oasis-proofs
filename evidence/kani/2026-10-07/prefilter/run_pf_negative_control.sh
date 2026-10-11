#!/usr/bin/env bash
# Negative control: evidence the harnesses CAN fail, not evidence of correctness.
# Copies the committed tree, breaks one rule per harness, runs all three. Aborts unless
# every mutation actually applied (Phase 1.4 lesson: a sed that silently matched nothing
# left one harness running on unmutated code and "passing").
set -u
source "$HOME/.cargo/env" 2>/dev/null
D="$HOME/oasis-kani-neg"
rm -rf "$D"; git clone -q "$HOME/oasis-kani" "$D" && git -C "$D" checkout -q -f "${1:?commit}" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD) + mutations:"
F="$D/oasis-rt/src/mesh/prefilter.rs"
# 1. the bucket grants a token even when empty  -> proof_budget_never_exceeds_burst
sed -i 's/        if self.milli >= MILLI {/        if true {/' "$F"
# 2. refill is no longer capped at the burst     -> proof_budget_refill_capped
sed -i 's/        self.milli = (self.milli.saturating_add(added)).min(self.burst.saturating_mul(MILLI));/        self.milli = self.milli.saturating_add(added);/' "$F"
# 3. the parser accepts a buffer far too short   -> proof_v0c_parse_total (panics)
sed -i 's/    if env.len() < MESH_V0C_HEADER_LEN || \&env\[..6\] != SPORE_V0C_MAGIC {/    if env.len() < 6 || \&env[..6] != SPORE_V0C_MAGIC {/' "$F"
git -C "$D" diff --stat; git -C "$D" diff | grep '^[-+] '
n=$(git -C "$D" diff | grep -c '^+ ')
[ "$n" -eq 3 ] || { echo "ABORT: expected 3 mutated lines, got $n"; exit 4; }
cd "$D/oasis-rt" || exit 3
cargo kani --lib --harness proof_budget_never_exceeds_burst --harness proof_budget_refill_capped --harness proof_v0c_parse_total -Z unstable-options -Z stubbing --harness-timeout 900s --output-format terse 2>&1 | grep -vE "^\s+(Compiling|Checking)"
echo "[$(date -u +%FT%TZ)] cargo kani exit code ${PIPESTATUS[0]}"
