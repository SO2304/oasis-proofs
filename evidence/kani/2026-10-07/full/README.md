# Kani — the FULL suite (Phase 2.2), first local run

Phase 2.2 of `prompts/OASIS_VS_VERIDIFY.md` asks for the **whole** Kani suite, not only
the new harnesses. This is the first time it has been run to (near) completion anywhere;
before this, only the newly added harnesses of each phase were ever verified, and
`CLAUDE.md` carried the caveat "full CBMC pass not re-run".

Run in WSL on the Ubuntu reinstalled on 2026-10-07: kernel 6.18, **3 381 MB RAM**,
4 cores, `cargo-kani 0.68.0`, CBMC 6.11.0, gcc 15.2. `run_full_suite.sh b361555`,
`-j 1` (this host has OOM-killed `-j>1` before), `--harness-timeout 600s`.

| | |
| --- | --- |
| Harnesses in the tree | **152** |
| Started | 140 |
| **Verified** | **130** |
| Failed | 10 — **all of them `CBMC failed`, none a counterexample** |
| Never reached | 12 (the run was killed) |
| Wall clock | 13:10:14Z → 14:47:14Z (1 h 37 min) |
| Exit | 1, after `goto-instrument exited with status signal: 9 (SIGKILL)` |

**No property was refuted.** Every failure is CBMC itself dying — the host ran out of
memory, which is what the project's own note on this machine predicts (3.3 GB is not
enough for the heavy mesh/spinal harnesses). "CBMC failed" means *undetermined*, not
false; a refutation prints `Failed Checks:` with the assertion, as the negative controls
in the sibling directories do.

The 10 undetermined harnesses:

| Harness |
| --- |
| `branching::proof_m4_fitness_monotone_in_goal` |
| `efference::proof_m3_pain_monotone_in_magnitude` |
| `mesh::proof_ad_reset_count_predictable` |
| `mesh::proof_ae_alert_threshold_correctness` |
| `mesh::proof_ae_capacity_consumed_monotonic` |
| `mesh::proof_ae_snapshot_internal_consistency` |
| `mesh::proof_af_combined_pattern_no_dashboard_alert` |
| `mesh::proof_ag_reset_count_extrapolation` |
| `mesh::proof_ah_arithmetic_tolerance_symmetric` |
| `spinal::proof_spinal_assign_dims_stay_in_zone` |

Eight of the ten are the `mesh` Bloom-filter capacity/alert harnesses, which reason over
large integer arithmetic — the expected memory hogs.

## What this does and does not establish

- **Does:** 130 of the 152 harnesses hold, verified on a fresh checkout of the committed
  tree, with no counterexample anywhere in the suite. That includes every harness added
  in Phases 1.1 through 2.1.
- **Does not:** the remaining 22 (10 undetermined + 12 unreached) are **unknown**, not
  verified. Claiming "152/152" would be false.

To close the gap: a machine with ≥ 16 GB (or the `kani-proofs` CI job, which has a
90-minute budget and a hosted runner). The 10 undetermined ones should be re-run
individually there; several may also be reshapable to fit, as
`proof_enr_seq_never_decreases` was in Phase 1.2 after it hit the same wall.

Reproduce: `run_full_suite.sh <commit>` inside WSL.
