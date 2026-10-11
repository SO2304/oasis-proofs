# Kani — first run of the 16 harnesses added on 2026-10-06

Harnesses: 7 mesh v0B, 3 `tx_lease`, 3 `mesh_revocation`, 3 `actuation`.
Run in WSL (Ubuntu, 3.3 GB RAM, `cargo-kani 0.67.0`) with
`cargo kani --lib --harness … -Z unstable-options --harness-timeout 300s`
(`run_new_harnesses.sh`), on a fresh clone of the committed tree. These 16 were run
individually, not the full 129-harness suite (which doesn't fit in 3.3 GB).

| Run | Tree | Result | Log |
|---|---|---|---|
| 1 | `147f34a` | **13 verified, 3 FAILED**: all three `mesh_revocation` harnesses hit an *unwinding assertion in `memcmp`* (`#[kani::unwind(4)]` < the 8 iterations of a `[u8; 8]` comparison), so their properties were **undetermined**, not refuted | `kani_new_harnesses.log` |
| 2 | `dc7e4ef` | **16 verified, 0 failures** after raising the bound to 10 (harness-only change; `revocation_transition` untouched) | `kani_new_harnesses_rerun.log` |

Proven properties: the v0B parser never panics and its signed preimage binds the
payload digest, counter and network; the sender lease never issues above the
durable ceiling, issues nothing on a failed write, and resumes strictly above every
counter issued before a reboot; a revocation epoch never decreases, a rejected list
leaves state unchanged, and an applied list is a superset of the previous one; the
actuation gate acts only if all seven conditions hold, never acts when R14 is
unfavourable, and is total and deterministic.

Not done here: the full 129-harness CBMC pass (left to the `kani-proofs` CI job).
The run was triggered before fast-forwarding `main`, because CI runs every Kani
harness on each push to `main`.

**Erratum (added later on 2026-10-06, Phase 1.1):** the `cargo kani exit code 0`
line at the end of both logs is meaningless. `run_new_harnesses.sh` expanded `$?`
after a `$(date)` substitution in the same `echo`, so it printed date's status:
run 1 logged `0` despite its 3 failures. The verdicts in the table above come
from each log's `Complete - … verified, … failures` line, and they stand. The
logs are kept unchanged. The fixed runner is `pq/run_pq_harnesses.sh`, which logs
exit `1` for a refuted harness (`pq/kani_pq_run1.log`).
