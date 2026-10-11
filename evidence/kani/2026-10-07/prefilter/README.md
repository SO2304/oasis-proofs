# Kani — Phase 2.1 harnesses (relay pre-filter)

Harnesses added with `oasis-rt/src/mesh/prefilter.rs` (spec
`docs/specs/RELAY_PREFILTER_SPEC.md`). Run in WSL on a **freshly reinstalled** Ubuntu
(the previous one was destroyed by the rsync incident of 2026-10-07): kernel 6.18,
3 381 MB RAM, 4 cores, `cargo-kani 0.68.0`, CBMC 6.11.0, gcc 15.2.

| Run | Tree | Result | Exit | Log |
|---|---|---|---|---|
| 1 | `b361555` | **3 verified, 0 failures** (2.67 s, 4.99 s, 7.71 s) | 0 | `kani_pf_run1.log` |
| negative control | `b361555` + 3 mutations (not committed) | **0 verified, 3 failures**, as intended | 1 | `kani_pf_negative_control.log` |

Negative control (`run_pf_negative_control.sh`), one mutation per harness, and the
script aborts unless all three applied (the Phase 1.4 lesson: a `sed` that silently
matched nothing left a harness "passing" on unmutated code):

| Mutation | Harness | Failure |
|---|---|---|
| the bucket grants a token even when empty (`if self.milli >= MILLI` → `if true`) | `proof_budget_never_exceeds_burst` | `assertion failed: granted == burst` (plus a subtract overflow) |
| refill no longer capped at the burst (`.min(burst*MILLI)` dropped) | `proof_budget_refill_capped` | `assertion failed: b.tokens() <= burst` |
| the parser accepts a 6-byte buffer (`len < MESH_V0C_HEADER_LEN` → `len < 6`) | `proof_v0c_parse_total` | `index out of bounds` ×5 |

Proven properties (run 1):

| Harness | Property |
|---|---|
| `proof_budget_never_exceeds_burst` | for any rate ≤ 1000 and burst in 1..=24, at a single instant (no refill) the bucket grants exactly `burst` tokens and never more |
| `proof_budget_refill_capped` | after any elapsed time the available tokens never exceed `burst`, and a clock that goes backwards never increases them |
| `proof_v0c_parse_total` | `v0c_try_parse_header` never panics for any input; an accepted header implies the exact magic and a buffer of at least `MESH_V0C_HEADER_LEN`, and `payload_len` is read from the fixed offset |

Limits:

- **The ordering property — no Ed25519 verification without a valid link tag and within
  budget — is NOT proved here.** It runs through real X25519, HKDF, HMAC-SHA256 and
  Ed25519, which CBMC cannot tract. It is covered instead by the
  `ED_VERIFY_CALLS` counter tests in `oasis-rt/src/mesh/prefilter/tests.rs` (zero
  verifications on a bad tag, on an unknown forwarder, past the budget, and on a
  downgrade attempt) and by the silicon measurement
  (`evidence/silicon/2026-10-07/prefilter/`).
- The key derivation itself (`link_key`) is not modelled; its correctness rests on the
  RFC 4231 vector, the symmetry test and the upstream crates.
- Budgets are bounded to 24 in the harnesses, rates to 1000.
