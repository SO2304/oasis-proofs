#!/usr/bin/env bash
# Negative control (not evidence of correctness; evidence the harnesses can fail):
# copy the committed tree, break two rules in firmware.rs, run the two harnesses.
set -u
source "$HOME/.cargo/env" 2>/dev/null
D="$HOME/oasis-kani-neg"
rm -rf "$D"; git clone -q "$HOME/oasis-kani" "$D" && git -C "$D" checkout -q -f "${1:?commit}" || exit 2
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD) + mutations:"
F="$D/oasis-rt/src/firmware.rs"
sed -i 's/    if (i.manifest_version as u64) < i.floor {/    if false \&\& (i.manifest_version as u64) < i.floor {/' "$F"
sed -i 's/    floor.max(running_version as u64)/    running_version as u64/' "$F"
git -C "$D" diff --stat; git -C "$D" diff | grep '^[-+] '
cd "$D/oasis-rt" || exit 3
cargo kani --lib --harness proof_fw_install_requires_all_conditions --harness proof_fw_floor_never_lowers -Z unstable-options -Z stubbing --output-format terse 2>&1 | grep -vE "^\s+(Compiling|Checking)"
echo "[$(date -u +%FT%TZ)] cargo kani exit code ${PIPESTATUS[0]}"
