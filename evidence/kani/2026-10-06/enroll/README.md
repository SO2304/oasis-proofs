# Kani — Phase 1.2 harnesses (enrollment + ownership transfer)

Harnesses added with `oasis-rt/src/enrollment.rs` and `oasis-rt/src/ownership.rs`
(spec `docs/specs/ENROLLMENT_OWNERSHIP_SPEC.md`). Run in WSL (Ubuntu, 3.3 GB RAM,
`cargo-kani 0.67.0`) on a fresh clone of the committed tree with
`run_enroll_harnesses.sh <commit>`. Each log's third line records the exact harness
list it ran (run 1 ran 6 harnesses, run 2 ran 7).

| Run | Tree | Result | Exit | Log |
|---|---|---|---|---|
| 1 | `6cb7a8b` | 5 verified, 1 FAILED: `proof_enr_seq_never_decreases`, **CBMC ran out of memory**. The property was not refuted, only undetermined | 1 | `kani_enroll_run1.log` |
| 2 | `9fc14ba` | **7 verified, 0 failures** | 0 | `kani_enroll_run2.log` |

Between the two runs (commit `9fc14ba`, harness change only, `enrollment.rs` untouched):
- `proof_enr_seq_never_decreases` was reshaped. Run 1 used a symbolic registry of
  0 to 2 entries with whole-entry comparisons. A working-tree dev run with 0 or 1
  entries still ran out of memory (3.1 GB peak). The final harness uses one held
  entry with the same fingerprint, the update path where "never decreases" is the
  claim. It verifies in 10 s at 362 MB.
- The "other entries are untouched" part moved to its own harness,
  `proof_enr_other_entries_untouched`.
- **Negative control** (working tree, not committed): changing the rule from
  `enroll_seq <= held` to `<` (accepting an equal sequence, i.e. a replay) made
  `proof_enr_seq_never_decreases` fail
  (`assertion failed: a.enroll_seq > held.seq && d == EnrollDecision::Updated`).

Proven properties (run 2):

| Harness | Property |
|---|---|
| `proof_enr_revoked_never_enrolled` | for any registry of ≤ 2 entries: a revoked fingerprint is never enrolled; a rejection never yields a new registry |
| `proof_enr_seq_never_decreases` | a node already held is updated only with a strictly higher `enroll_seq`, which is installed; otherwise `StaleSeq` |
| `proof_enr_other_entries_untouched` | enrolling one node leaves another node's entry unchanged |
| `proof_enr_parse_total` | `parse_attestation` never panics; an accepted attestation has a known role and no reserved permission bit |
| `proof_own_transfer_requires_both_signatures` | `Transferred` only if an offer is pending (verified with the current owner's keys to become pending), the acceptance was verified with the offered keys, the sequence and offer digest match, and the sequence rises |
| `proof_own_offer_rules` | an offer becomes pending only with a sequence above the current one and a revocation list signed by the current owner; the same offer is never pending twice |
| `proof_own_accept_parse_total` | the acceptance parser never panics and accepts only its sub-type; nothing that short parses as an offer |

Limits: signature verification is not modelled (the decisions take its result as an
input); registries are bounded (≤ 2 entries); record encoding and decoding, which
involve SHA-256, are unit-tested only. The full 143-harness suite is left to the
`kani-proofs` CI job.
