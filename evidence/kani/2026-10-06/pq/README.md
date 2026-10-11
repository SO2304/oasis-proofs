# Kani — Phase 1.1 harnesses (OAU1 authority + OFR1 fragmentation)

Seven harnesses (six, then one more in run 3) added with `oasis-rt/src/authority.rs` and `oasis-rt/src/fragment.rs`
(spec `docs/specs/PQ_AUTHORITY_SPEC.md`). Run in WSL (Ubuntu, 3.3 GB RAM,
`cargo-kani 0.67.0`) on a fresh clone of the committed tree, with
`run_pq_harnesses.sh <commit>` (runs 1-2) and `run_pq_harnesses_stub.sh <commit>`
(run 3, adds the stubbed harness and `-Z stubbing`).

| Run | Tree | Result | Exit | Log |
|---|---|---|---|---|
| 1 | `d5dfebd` | **5 verified, 1 FAILED**: `proof_auth_precheck_no_downgrade` refuted (`Failed Checks: "known kind and suite only"`) | 1 | `kani_pq_run1.log` |
| 2 | `3e67254` | **6 verified, 0 failures** | 0 | `kani_pq_run2.log` |
| 3 | `19053d7` | **7 verified, 0 failures** (the 6 above + `proof_frag_reassembler_never_panics`, `-Z stubbing`) | 0 | `kani_pq_run3.log` |
| 4 | `be3d47b` | **7 verified, 0 failures**: rerun after `authority.rs` switched its ML-DSA-44 verifier to `libcrux-ml-dsa` (harnesses unchanged; checks that the crate still compiles and verifies under Kani) | 0 | `kani_pq_run4.log` |

**Run 1 found a real defect.** `AuthPolicy::min_suite` returns `u8::MAX` for an
unknown kind, and `suite_rank(u8::MAX) == 0`, so `precheck` accepted an unknown
kind with an unknown suite (rank 0 ≥ rank 0). It was not reachable through
`verify_authority`, because `parse_oau1` rejects unknown kinds and suites first,
but `precheck` relied on that. Fixed in `3e67254` (`precheck` returns
`UnknownKind` when the required rank is 0), with unit regression test
`pq_precheck_refuses_unknown_kind_and_suite`. The harness itself was not changed
between the two runs.

Proven properties (runs 3 and 4):

| Harness | Property |
|---|---|
| `proof_auth_hybrid_requires_both` | the hybrid suite is satisfied iff both signatures verified; a reserved/unknown suite is never satisfied |
| `proof_auth_policy_never_lowers` | from any policy reachable by two raises, a third `raise` never lowers any kind's minimum, never installs an unknown suite, and POLICY stays hybrid |
| `proof_auth_parse_total` | `parse_oau1` never panics on any input ≤ 96 bytes; an accepted message has a known kind, a supported suite, a 64-byte Ed25519 signature and exact length |
| `proof_auth_precheck_no_downgrade` | `precheck` passes only on the right network, for a known kind, with a suite at least as strong as the policy requires |
| `proof_frag_parse_in_bounds` | `parse_ofr1` never panics on any input ≤ 40 bytes; an accepted fragment is non-empty, lies inside the message and inside its own stride |
| `proof_frag_reassembler_never_panics` | two arbitrary byte strings (≤ 20 B) from 3 possible origins at arbitrary times: `Reassembler::push` never panics, never writes outside a slot buffer, never holds more than 2 slots. SHA-256 is stubbed with an arbitrary digest (`#[kani::stub]`), since the bounds property doesn't depend on it |
| `proof_frag_completion_mask` | the completion bitmap has exactly `count` bits for every `count` in 1..=32 and covers every valid index |

Limits, stated plainly:

- Signature verification (Ed25519, ML-DSA-44) is **not** modelled. These proofs
  cover the decision rules around it. ML-DSA-44 correctness is tested (NIST ACVP
  sigVer 15/15, byte-for-byte match with `libcrux-ml-dsa` over 8 seeds), not proven.
- Inputs are bounded: 96 bytes for `parse_oau1` (so the 2 420-byte ML-DSA branch is
  out of reach of that harness) and 40 bytes for `parse_ofr1`.
- `proof_frag_reassembler_never_panics` covers two pushes with chunks ≤ 4 bytes,
  with SHA-256 stubbed. Longer sequences and the hash check itself are unit-tested.
  Negative control (working tree, not committed): weakening `parse_ofr1`'s chunk-length
  check to `chunk.len() > s` made this harness and `proof_frag_parse_in_bounds` both
  fail (0 verified, 2 failures).
- The full 136-harness suite was not run locally (it doesn't fit in 3.3 GB). That
  is left to the `kani-proofs` CI job.

Runner fix: the 2026-10-06 E/F runner (`../run_new_harnesses.sh`) printed `$?`
after a `$(date)` substitution in the same `echo`, so it always logged `exit code 0`,
including for its failed run. `run_pq_harnesses.sh` captures the code first. Run 1
above was redone with the fixed script (same tree, same result) so that the
committed log shows the non-zero exit.
