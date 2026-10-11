# Phase 1.1 on silicon — ML-DSA-44 on RP2040

Spec: `docs/specs/PQ_AUTHORITY_SPEC.md` (§4 crate choice, §5 measurements, §6
silicon tests). Three RP2040 clone boards (A, B, C), Cortex-M0+ at 125 MHz, no FPU,
264 KB RAM. Logs are LF-only and come straight from USB-CDC
(`OASIS|board|test|PASS/FAIL|value|unit|git_stamp`).

## 1. Bake-off: which ML-DSA-44 verifier goes on the device

Firmware `oasis-silicon-test/src/bin/pq_bench.rs` at stamp **`98ecb35`**. It
verifies one hybrid `OAU1` revocation (2 526 B, signed on the PC by
`oasis-operator-key/examples/pq_payloads.rs`; public key and blob in
`oasis-silicon-test/src/pq/`). Time is median/min/max over K = 5 single runs on the
1 MHz hardware timer. Peak stack is measured by painting the free stack with a known
word, running the verifier once, and finding the lowest overwritten word. That gives
a lower bound on bytes written below the caller's stack pointer; USB is polled, so no
interrupt shares the stack. 3 boards × 3 runs = 9 runs, 171 lines, **0 FAIL**
(`10_bench_{A,B,C}_run{1,2,3}.log`).

| Operation | Median of the 9 run medians | Spread of run medians | Peak stack |
|---|---:|---:|---:|
| Ed25519 verify (`ed25519-compact`, same message) | 177.86 ms | 177.83–177.89 ms | 8 548 B |
| ML-DSA-44 verify, RustCrypto `ml-dsa` 0.1.1 | 177.87 ms | 177.87–177.88 ms | **84 020 B** |
| Full hybrid gate `verify_authority` (ml-dsa + Ed25519) | 357.93 ms | 357.88–357.97 ms | 84 180 B |
| ML-DSA-44 verify, `libcrux-ml-dsa` 0.0.10 (incl. copying key + signature into its types) | 198.16 ms | 198.11–198.22 ms | **44 796 B** |

Correctness on every run and every board: the valid signature is accepted and one
flipped bit (signature byte 1000) is refused, by both implementations.
`PQ_HEAP used=52` = only the 51-byte signed-message `Vec`; neither verifier allocates.

The Ed25519 figure matches the earlier, independent T6 measurement
(`v0A_verify` median 176.55 ms, `../board_A_run1.log`). That ML-DSA-44 under
`ml-dsa` lands within 0.1 % of Ed25519 is a coincidence of two different
computations: the stack (84 KB vs 8.5 KB) and the code are entirely different.

**Flash** (`00_sizes.log`, `llvm-size -B` on `pq_bench`, text = code + rodata):

| Verifiers linked | text | added vs none |
|---|---:|---:|
| none (Ed25519 only) | 68 544 B | — |
| `ml-dsa` | 85 180 B | +16 636 B |
| `libcrux-ml-dsa` | 186 208 B | +117 664 B |
| both | 201 236 B | +132 692 B |

(Each verifier figure includes the 1 312-byte public key.)

**Against the public baseline** (PQClean C, arXiv 2603.19340): verification there
takes 44.0 ms and 9.4 KB of stack. Both pure-Rust crates are **4.0–4.5× slower** and
need **4.8–8.9× more stack** on this core (taking 9.4 KB as 9 400 B; 4.7–8.7× if
it means KiB). We did not try to optimise either crate.

**Decision: `libcrux-ml-dsa` 0.0.10 verifies on the device**, applying the spec's
rule ("keep the safest that fits in memory"):

- both fit (264 KB RAM, 2 MB flash);
- libcrux's arithmetic, NTT and serialization are formally verified (hax/F*), while
  `ml-dsa`'s README says it has never been independently audited;
- libcrux uses **47 % less stack** (44.8 KB vs 84.0 KB). On a 264 KB part that also
  protects the firmware's heap and stack budget, and a stack overflow here is a
  HardFault;
- the cost is +11 % time (+20 ms per verification) and +101 KB flash compared with
  `ml-dsa`.

`ml-dsa` remains the independent oracle: it signs on the host (`pq_payloads`), and on
the PC every test signature is checked by both implementations, plus the 15 NIST
ACVP sigVer vectors.

Version pin: the first run (`09_bench_A_lx0.0.11pre1.log`, `00_sizes_lx0.0.11pre1.log`,
stamp `1b00414`) used `libcrux-ml-dsa 0.0.11-pre.1`, a pre-release published the same
day. It was re-pinned to the latest stable release, 0.0.10 (2026-07-15), in `98ecb35`
before the 9 runs above. Code size within 4 bytes, times within 0.1 %.

Lockfile note: commit `98ecb35` pins `libcrux-ml-dsa = "=0.0.10"` in
`oasis-silicon-test/Cargo.toml`, but its `oasis-silicon-test/Cargo.lock` still
listed 0.0.11-pre.1, because the lock was committed before the silicon crate was
rebuilt. The exact pin forced cargo to re-resolve at build time, so the images
above contain 0.0.10. The lockfile actually used is committed together with this
report.

## 2. The device path after the switch (stamp `be3d47b`)

`oasis_rt::authority::mldsa44_verify` now calls libcrux. `pq_bench` was rewired so that
its labels stay true: `PQ_RC_*` calls RustCrypto `ml-dsa` directly, `PQ_LX_*` goes
through `oasis_rt` (the production path), and `PQ_AUTH_*` is the full gate. 3 boards ×
1 run × K = 5, 57 lines, **0 FAIL** (`11_bench_device_path_{A,B,C}.log`).

| Operation | Run medians (A / B / C) | Peak stack |
|---|---|---:|
| **Full hybrid gate `verify_authority`** (parse, precheck, ML-DSA-44 via libcrux, Ed25519) | 377.08 / 377.04 / 377.10 ms | **48 724 B** |
| ML-DSA-44 via `oasis_rt` (libcrux) | 197.99 / 198.06 / 198.03 ms | 48 564 B |
| ML-DSA-44, `ml-dsa` called directly | 177.98 / 177.97 / 178.00 ms | 102 476 B |

**Peak stack depends on the call site, not only on the crate.** Through `oasis_rt`,
libcrux takes 3 768 B more than in the bake-off closure (48 564 vs 44 796). That is
the copy of the key and the signature into owned arrays (1 312 + 2 420 = 3 732 B).
RustCrypto `ml-dsa` called directly peaks at 102 476 B, against 84 020 B through the
old `oasis_rt` function, because inlining differs. libcrux uses about half as much
in both arrangements, so the decision holds. The figure that sizes the firmware is
the gate: **48.7 KB of stack, 377 ms**.

## 3. Hybrid authority messages over the A→B→C wire (stamp `1a9b461`)

Firmware `uart_mesh` with `src/pq.rs`: the authority policy lives in two flash slots,
there is one `OFR1` reassembly per v0B origin, and `verify_authority` runs under the
live policy with on-chip time and stack measurement. Store-and-forward: a node never
relays a fragment as-is. It re-originates the message under its own counters, after
a lease reservation, and only if the message changed its state.

Images (`firmware_uart_pq_{A,B,C}.uf2`): text 265 040 B on A/B (C, which also
compiles the actuator code, 288 144 B), against 139 640 B for the E/F firmware
`6daa0bc`. RAM statics are unchanged at 98 340 B (including the 96 KiB heap), which
leaves about 172 KB for the stack.

Fragmentation: v0B header 99 B + `OFR1` 201 B = one 300-byte frame, so a 2 526-byte
hybrid revocation takes **14 fragments**. Host harness in `harness/`; every payload
sent is in `payloads/` (hex, built by `pq_payloads`). The wiring is one-way
(A.GP0→B.GP1, B.GP0→C.GP1), so A only originates and C's re-originations go nowhere.

Before the campaign: status (`20_*`, which also shows that B and C restored their E/F
ORV1 list, epoch 2, with the new 4 KiB slot), factory reset `!` on all three (`21_*`),
strict v0B `K` (`22_*`: epoch 0, default policy, `legacy_orv1_allowed=true`).

| # | What was sent (from A) | B | C | Logs |
|---|---|---|---|---|
| 1 | Hybrid revocation, epoch 1, 14 fragments | 14/14 reassembled, `Revocation(Applied)` epoch 1, 383.3 ms, 49 244 B stack; re-originated 14 fragments | 14/14 from `bb`, `Applied` epoch 1, 381.7 ms | `30_*` |
| 2a | Hybrid revocation epoch 2, fragment 5 altered **after** fragmentation (`@T5`; A's v0B signature on it is valid) | 14/14 received, **`rejected_hash_mismatch`** on completion, no `AUTH`, nothing sent | nothing received | `31_*` |
| 2b | Same message with 1 bit of the signed content flipped on the PC (byte 44), cleanly re-fragmented | reassembled, **`Rejected(BadSignature)`** in 203.3 ms (ML-DSA-44 fails first, Ed25519 not attempted), nothing sent | nothing received | `32_*` |
| — | Liveness: status after 2a/2b | `frames=42`, `tx=14` | `frames=14` (only test 1): its silence above is B's refusal, C was listening | `33_*` |
| 3a | **Control**: legacy Ed25519-only `ORV1`, epoch 2, before any policy change | `Applied`, relayed | `Applied` | `34_*` |
| 3b | Hybrid `POLICY`: revocations now require the hybrid suite | `Policy { changed: true, persisted: true }`, 381.5 ms, re-originated | same, 379.9 ms | `35_*` |
| 3c | Legacy `ORV1`, epoch 3 | **`LegacyRefused`** (`min_suite_revocation=3`), epoch stays 2, not relayed | nothing received | `36_*` |
| 3d | Ed25519-only `OAU1` revocation, epoch 3 (1 fragment) | **`Rejected(Downgrade)`** in **4.19 ms** in total (no signature verified), not relayed | nothing received | `37_*` |
| 3e | Hybrid revocation, epoch 3 | `Applied` epoch 3, 382.7 ms, re-originated | `Applied` epoch 3, 381.3 ms | `38_*` |
| P | **Real power cut of B** (USB unplugged by the operator after `39_*`) | after reboot (uptime 17.8 s, `boot_id` 0→1279, frame counters reset): **epoch 3, 3 revoked, `min_suite_revocation=3`, `legacy_orv1_allowed=false`** | — | `39_*`, `40_*` |
| P1 | Legacy `ORV1`, epoch 4, after the power cut (B back in strict mode, `41_*`) | **`LegacyRefused`**, epoch stays 3 | nothing received | `42_*` |
| P2 | Hybrid revocation, epoch 4, after the power cut | `Applied` epoch 4, 380.9 ms; re-originated under counters 1280–1293 (lease resume 1279) | `Applied` epoch 4 (counters fresh) | `43_*` |

What P shows: the epoch-3 list restored at boot is the **hybrid `OAU1` blob**, the
newest slot, re-verified at boot with ML-DSA-44 and Ed25519 under the default policy.
A failed restore would leave epoch 0, because the loader doesn't fall back to the
older ORV1 slot. The raised policy also survived the cut, because both of its slots
had been written.

On-chip figures: the 8 accepted or policy verifications took **379.2–383.3 ms**
(`verify_us`). That window includes painting and scanning the free stack. The
downgrade case (3d: 4.19 ms in total, no signature work) bounds that overhead at
about 4 ms, consistent with the bench's clean 377 ms (§2). Peak stack depth was
**49 244 B** on every full verification. On the downgrade path it was 38 144 B:
`verify_authority` reserves its frame, including inlined libcrux state, at function
entry, so the depth is reached before the precheck refuses.

Log audit: 46 logs, 756 lines, all stamped `1a9b461`, LF only. No `DROP`,
`FRAMER_CRC_FAIL`, `FRAG_TX_FAIL`, `LEASE_FAIL` or bad-hex line in the campaign. The 5
empty logs are C's expected silences (2a, 2b, 3c, 3d, P1). Two `RXF` lines
(`35_policy_raise_{B,C}.log`, line 13) have one extra field: that trace prints a
fragment's last 3 bytes, and one of them was a literal `|`. Logging artifact only.

## 4. Limits

- **Wired UART, not radio.** No LoRa, no loss, one fixed path, one-way wiring.
- **Store-and-forward cost.** Each hop verifies 14 v0B fragments (~178 ms each),
  then the gate (~380 ms), then re-signs 14 fragments (~341 ms each, T6 `v0A_sign` in
  `../board_A_run1.log`): 14 × 178 + 380 + 14 × 341 ms ≈ 7.6 s of computation per hop
  for one hybrid revocation. **⚠️ Wrong: see the erratum at the end (≈ 5.5 s).** It is acceptable for rare
  authority messages and not for orders, which is why orders stay Ed25519 only
  (spec §1). End-to-end latency was not measured (no timestamps in the logs).
- **DoS.** A node holding a valid v0B key can make a relay run the 380 ms gate by
  sending well-formed fragments of a bogus message (test 2b). One reassembly per
  origin, 2 slots in total, and revocation of the origin bound this, but nothing
  rate-limits it yet. The per-relay prefilter is Phase 2.
- **Kinds 2–4** (enrollment, firmware manifest, ownership) are verified, then
  refused as `Unsupported`, until Phases 1.2–1.3.
- **A's own policy** is not raised by sending the policy message (an originator
  doesn't process its own messages); a real deployment provisions every node.
- **Not proven on silicon:** a torn flash write of the policy or a revocation slot
  during a real power cut (unit-tested with a simulated tear); the 2 MB flash layout
  under a real firmware update.
- `verify_us` includes about 4 ms of stack measurement; §2's 377 ms is the clean figure.
- The ML-DSA-44 implementation is formally verified only in part (arithmetic, NTT,
  serialization) and is pre-1.0. No external audit.

## Erratum (2026-10-06, found during Phase 1.2)

On `uart_mesh` a v0B **sign** takes **178 ms** (`../enroll/10_reflash_paced_A.log`:
`v0b_sign_us=178065`), not the 341 ms I took from the T6 suite, which is a different
firmware. Two consequences:

1. The per-hop computation in §4 is about **5.5 s** (14 × 185 + 380 + 14 × 178 ms),
   not 7.6 s.
2. I had argued that B keeps up because A signs more slowly than B verifies. That was
   wrong: A's period was ~204 ms (sign + 26 ms on the wire), against B's ~185 ms of
   verification plus logging. The Phase 1.1 runs above passed with that ~10 ms margin
   (0 CRC failures in their logs). Phase 1.2 added per-frame work and B's FIFO
   overflowed (`../enroll/REPORT.md` §3). Commit `4713703` adds a 100 ms gap after
   each fragment.

The Phase 1.1 results stand: every fragment arrived and every decision is in the
logs. They were obtained without a safety margin on the wire.
