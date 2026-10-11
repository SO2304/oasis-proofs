#!/usr/bin/env bash
# First Kani run of the 16 harnesses added on 2026-10-06 (v0B, tx_lease, revocation,
# actuation). Run inside WSL; the caller enforces the timebox with `timeout`.
set -u
source "$HOME/.cargo/env" 2>/dev/null
echo "[$(date -u +%FT%TZ)] host: $(uname -r), $(free -m | awk 'NR==2{print $2" MB RAM"}'), $(cargo kani --version 2>&1 | head -1)"
D="$HOME/oasis-kani"
if [ -d "$D/.git" ]; then
  git -C "$D" fetch -q /mnt/c/dev/oasis oasis-e-f-attacks && git -C "$D" checkout -q -f FETCH_HEAD
else
  git clone -q --branch oasis-e-f-attacks /mnt/c/dev/oasis "$D"
fi
echo "[$(date -u +%FT%TZ)] tree: $(git -C "$D" rev-parse --short HEAD)"
cd "$D/oasis-rt" || exit 3
H=""
for h in \
  proof_v0b_parse_never_panics_full proof_v0b_parse_never_panics_short proof_v0b_parse_never_panics_with_payload \
  proof_v0b_preimage_binds_payload_digest proof_v0b_preimage_binds_counter proof_v0b_preimage_binds_network \
  proof_v0b_preimage_domain_separated_and_consistent \
  proof_tx_lease_resume_strictly_above_issued proof_tx_lease_never_issues_above_durable_ceiling \
  proof_tx_lease_failed_store_issues_nothing \
  proof_rev_epoch_never_decreases proof_rev_rejected_leaves_state_unchanged proof_rev_applied_is_superset \
  proof_act_requires_all_conditions proof_r14_unsafe_never_acts proof_decision_total_and_deterministic; do
  H="$H --harness $h"
done
echo "[$(date -u +%FT%TZ)] cargo kani --lib$H"
cargo kani --lib $H -Z unstable-options --harness-timeout 300s --output-format terse 2>&1
echo "[$(date -u +%FT%TZ)] cargo kani exit code $?"
