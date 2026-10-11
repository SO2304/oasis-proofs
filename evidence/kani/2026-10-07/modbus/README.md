# Kani — Phase 1.4 harnesses (Modbus RTU gateway)

Harnesses added with `oasis-rt/src/modbus_gateway.rs` (spec
`docs/specs/MODBUS_GATEWAY_SPEC.md`). Run in WSL (Ubuntu, 3.3 GB RAM, `cargo-kani 0.67.0`)
on a fresh checkout of the committed tree.

| Run | Tree | Result | Exit | Log |
|---|---|---|---|---|
| 1 | `a39d5fe` | **3 verified, 0 failures** (77.2 s, 213.3 s, 95.1 s) | 0 | `kani_mb_run1.log` |
| negative control 1 | `a39d5fe` + mutations | **invalid**: only mutation 1 applied (see below) | 1 | `kani_mb_negative_control_run1_mutation2_not_applied.log` |
| negative control 2 | `a39d5fe` + 2 mutations (not committed) | **0 verified, 2 failures**, as intended | 1 | `kani_mb_negative_control_run2.log` |

Negative control (`run_mb_negative_control.sh`):
- **A frame whenever the register rules pass, even without `Act`:**
  `proof_mb_no_frame_without_act` fails with `assertion failed: d == Decision::Act`.
- **Lower bound of each register range not checked:** `proof_mb_frame_matches_rules`
  fails with `assertion failed: o.values[i] >= r.min && o.values[i] <= r.max`.

**Control 1 did not test `proof_mb_frame_matches_rules`.** Its sed pattern for mutation 2
assumed the match arm spans several lines, but `cargo fmt` (with `oasis-rt/rustfmt.toml`)
keeps it on one line. The pattern never matched, so that harness ran on unmutated code
and passed. The log's diff shows a single mutated line. The script now aborts unless
exactly two lines changed.

Proven properties (run 1):

| Harness | Property |
|---|---|
| `proof_mb_no_frame_without_act` | for all orders, contexts, 3-rule maps and last sequences: a frame exists only if the decision is `Act`, i.e. v0B verified, authorized, not revoked, R14-safe, `boot_id` equal, `now ≤ deadline ≤ now + 10 s`, rules `Ok`, and `cmd_seq` above the last executed |
| `proof_mb_frame_matches_rules` | a produced frame targets the configured unit, writes only registers of the map (no wrap past 0xFFFF), each value within its range, and encodes exactly the order (FC, start, quantity, byte count, values big-endian) with a valid CRC-16/MODBUS |
| `proof_mb_parsers_total` | `parse_omb1` and `check_response` never panic; an accepted order has exactly the length its count implies, a supported FC (06 or 16) and zero values past its count |

Limits:
- Signature verification, registry, revocation and R14 are inputs to the rule, not
  modelled. Their own proofs are elsewhere (v0B, enrollment, revocation, actuation).
- Register maps are bounded to 3 rules.
- That the firmware writes UART1 only with frames from this rule (`mb_exchange`, a
  single call site) is checked by reading the code, not proven.
