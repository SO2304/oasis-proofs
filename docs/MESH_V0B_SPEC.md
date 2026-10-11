# MESH v0B (`SPORE\x0B`) — specification (Phase 1, before code)

**Goal (verifiable, one sentence):** every relay verifies the *origin*, the
*content*, the *freshness* and the *network* of each message; a forged, modified,
replayed, or foreign-network message is rejected **at the first hop**, even after
the relay reboots.

**v0B is more secure, not faster.** Performance is measured and reported, never
traded against security. This spec adds v0B *alongside* v8/v9/v0A — none of their
behaviour changes, and the existing workspace test suite must stay green.

All facts below were checked against the current tree (branch `mesh-v0b`,
from `silicon-test-3pico`): `oasis-rt/src/mesh.rs`, `oasis-rt/src/spore_crypto.rs`,
`oasis-rt/Cargo.toml`, and the silicon reports.

---

## 0. Why v0B — the four v0A defects it closes (verified in code)

1. **Content is not signed.** `mesh_v10_sign` signs `magic‖msg_id‖origin_fp`
   (22 B) only — [mesh.rs:172](../oasis-rt/src/mesh.rs#L172). On silicon, 12/50
   payload bit-flips were *accepted* (evidence/silicon/2026-10-04 §12b). Worse, a
   malicious relay can keep the signature, swap the payload, and get the forged
   message **remembered**; the real message (same `msg_id`) is then dropped as a
   `"duplicate"` ([process:894](../oasis-rt/src/mesh.rs#L894)) — a message-
   **suppression** attack.
2. **No verifiable freshness.** `msg_id = origin_msg_id(fp, tx_counter)` is a hash
   ([mesh.rs:949](../oasis-rt/src/mesh.rs#L949)); the receiver cannot check that
   the counter increases. Anti-replay is the RAM dedup only (`seen` VecDeque 4096
   + Bloom). A signed message is **accepted again** after a relay reboot, a Bloom
   reset, or a dedup-cache overflow. `tx_counter` is explicitly "not persisted;
   caller's responsibility" ([mesh.rs:541](../oasis-rt/src/mesh.rs#L541)).
3. **No domain separation.** The signature carries no network identifier, so an
   origin registered on two networks is replayable across them.
4. **Revocation is not enforced by relays.** `MeshRouter` has no revocation set;
   a revoked origin is rejected (if at all) only at the application layer, not at
   the first hop.

---

## 1. Envelope format — `SPORE\x0B`

Little-endian. Header = **99 bytes**, then payload.

| offset | len | field | signed? | mutable per hop? |
|---:|---:|---|:--:|:--:|
| 0 | 6 | magic `SPORE\x0B` | ✔ (domain string, see §2) | no |
| 6 | 8 | `network_id` | ✔ | no |
| 14 | 8 | `origin_fp` | ✔ | no |
| 22 | 8 | `counter` (u64, cleartext **and** signed) | ✔ | no |
| 30 | 1 | `ttl` | ✘ | **yes** (−1 each hop) |
| 31 | 2 | `hops` (u16) | ✘ | **yes** (+1 each hop) |
| 33 | 2 | `payload_len` (u16) | ✔ | no |
| 35 | 64 | Ed25519 `signature` | — | no |
| 99 | n | `payload` | ✔ via digest | no |

Constants: `SPORE_V0B_MAGIC = b"SPORE\x0B"`, `MESH_V0B_HEADER_LEN = 99`,
`MESH_V0B_MAX_PAYLOAD = 65535` (bounded by `payload_len: u16`).

**`msg_id` is dropped as an identity/signed field.** Justification: in v0A `msg_id`
was both the dedup key and (a hash of) the counter, but the receiver could not
verify it. In v0B the identity of a message is the pair **`(origin_fp, counter)`**,
both explicit and signed. Freshness and accept-once are enforced by the per-origin
counter window (§4), which *is* verifiable. An internal `msg_id =
origin_msg_id(origin_fp, counter)` may still be computed as a cheap first-level
dedup key for the existing Bloom/`seen` fast-path, but it is **not** security-
bearing and is updated only *after* full verification (§3). The authoritative
anti-replay is the persisted counter window, never the Bloom.

---

## 2. Signed data (explicit domain separation)

```
signed := "OASIS-MESH-v0B"            (14-byte ASCII domain tag)
        ‖ network_id        (8)
        ‖ origin_fp         (8)
        ‖ counter           (8, LE)
        ‖ payload_len       (2, LE)
        ‖ SHA-256(payload)  (32)     // sha2 0.11, no_std — oasis-rt/Cargo.toml:17
```
= 72 bytes, Ed25519-signed with the origin's key (`ed25519-compact` 2.2.0).

- **Content is bound** through `SHA-256(payload)`: changing any payload byte
  changes the digest, so the signature no longer verifies.
- **Network is bound**: a message signed for network A cannot be re-presented as
  network B; and a foreign-network message is rejected *before* the signature
  check by the cheap `network_id` filter (§3), so cross-network replay costs an
  attacker nothing on the defender but is still refused.
- `payload_len` is signed and must equal the actual payload length (guards
  truncation/extension that leaves the digest input ambiguous).
- The domain tag prevents a v0B signature from ever being valid as any other
  OASIS signature context, and vice-versa.

---

## 3. Relay verification order (cheapest → most expensive; verify **before** remember)

A message mutates relay state (`counter` window, dedup cache) **only at step 7**,
after every check has passed. Steps 1–6 are read-only.

| # | check | failure → `Drop(reason)` | cost |
|---:|---|---|---|
| 1 | `len ≥ 99` and magic == `SPORE\x0B` | `"mesh envelope too short"` / `"bad mesh magic"` | ~0 |
| 2 | `network_id == my_network_id` | `"foreign network"` | ~0 |
| 3 | `origin_fp` in registry **and not revoked** | `"unknown sender"` / `"origin revoked"` | ~0 (set lookup) |
| 4 | `ttl ≤ MAX_TTL`, `hops ≤ MAX_TTL`, `ttl+hops ≤ MAX_TTL`, `payload_len == payload.len()` | `"ttl/hops out of range"` / `"length mismatch"` | ~0 |
| 5 | freshness **pre-check** `counter_tracker.is_stale(fp, counter)` is false (read-only) | `"stale counter"` | cheap |
| 6 | Ed25519 verify of §2 signed data (incl. `SHA-256(payload)`) | `"bad mesh signature"` | **~176 ms on M0+** |
| 7 | `counter_tracker.check_and_update(fp, counter)` (authoritative accept-once + window advance; **persisted**) | `"stale counter"` / `"replay detected"` | cheap + 1 flash-lease write (§5) |
| 8 | (optional) fast dedup `remember(msg_id)` | — | cheap |
| 9 | `ttl == 0` → `Arrived{forward:false}`; else `ttl−1`, `hops+1`, `Arrived{forward:true}` | — | ~0 |

Step 5 is a non-authoritative early-out that avoids paying step 6 for obvious
replays. It reads but never mutates, so a spoofed high counter can at worst force
one signature verify (a bounded, link-rate-limited DoS — accepted, since v0B
prioritises security over speed). Step 7 is the only writer and runs only after
the signature verifies, which is exactly the "verify-before-remember" rule.

---

## 4. Freshness — reuse `CounterTracker` (already in the tree)

`spore_crypto::CounterTracker` ([spore_crypto.rs:1078](../oasis-rt/src/spore_crypto.rs#L1078))
is an IPsec RFC 4303 §3.4.3 per-sender tracker: `highest` + 128-bit `bitmap`,
LRU-bounded over senders. Reused verbatim:

- `check_and_update(fp, counter)` → `Ok(())` on first sight of an in-window or
  advancing counter; `Err("counter too old (outside sliding window)")` or
  `Err("replay detected (bit set in sliding window)")` otherwise. (v0B maps both
  to the `Drop` reasons in §3.)
- `is_stale(fp, counter)` → read-only pre-check (step 5).
- Window **never moves backward** (monotone `highest`); within `[highest−127,
  highest]` a gap is accepted once, a set bit is a replay → **reorder up to 127
  positions accepted exactly once**.
- Persistence: `to_bytes` / `from_bytes` / `save_to_file` (`CTR\x03` format,
  [spore_crypto.rs:1209](../oasis-rt/src/spore_crypto.rs#L1209)) → the relay's
  freshness state survives reboot. This is what defeats the reboot/Bloom-reset
  replay (defect 2), independently of the RAM Bloom.

The v0B router owns one `CounterTracker` plus a `revoked: HashSet<[u8;8]>`.

---

## 5. Unsigned fields (`ttl`, `hops`) and what a malicious relay can do

`ttl`/`hops` must change at each hop, so they cannot be signed. Honest bound,
enforced on receipt (step 4): `ttl ≤ MAX_TTL`, `hops ≤ MAX_TTL`, `ttl+hops ≤
MAX_TTL` (`MESH_V0B_MAX_TTL`, default 8 = `DEFAULT_TTL`).

**Honest statement of the limit:** a malicious relay *can* reset a dying message's
`ttl` back up to `MAX_TTL` (the field is unauthenticated), so `ttl`/`hops` alone do
**not** bound total propagation. The hard anti-amplification guarantee is **accept-
once** (§4): the same `(origin_fp, counter)` is accepted at most once per honest
relay because its bitmap bit is then set — so a re-energised message cannot be re-
delivered to any honest node that already saw it. `ttl`/`hops` bound honest-path
length; the signed counter window bounds flooding. This is the property v0B
actually proves, and the comparison doc (Phase 4) states it as such.

### Counter persistence on RP2040 — implemented (receiver) + open gap (sender)

**Receiver — DONE and silicon-proven (T8).** The relay's `CounterTracker`
serialization (`CTR\x03`) is written to the last 4 KiB flash sector via
`rp2040-flash`'s RAM-safe bootrom helpers and restored on boot **before** any
v0B envelope is processed. Verified across a real USB power-cut on 2026-10-06:
`a_last_seen=165` came back from flash after RAM was wiped, and the old counter
was then refused `stale counter`. See
`evidence/silicon/2026-10-06/REPORT_MESH_V0B.md` §4.

Flash wear: persisting on every message would wear the sector (≈100 k erase
cycles). Production policy is write-coalescing — persist at most once per `L`
messages (`L = 256`); the silicon test flushes on demand (`P`) instead, which
persists the *exact* window and is strictly stronger for the test.

**Sender — DONE and silicon-proven (2026-10-06 follow-up).** T8 had found the
liveness gap: a rebooted origin restarted at counter 1 and every relay that
persisted it refused all its messages. `oasis_rt::tx_lease` closes it: the sender
persists a counter *ceiling* ahead of use (blocks of `L = 256`), never issues a
counter above the durable ceiling, and resumes **at** the persisted ceiling after
boot. `DualSlotStore` alternates two checksummed slots so a torn write leaves the
previous ceiling readable. 9 tests (incl. 10 000 random reboots with ~2 % torn
writes, no counter reused; 40 writes per 10 000 messages) and 3 Kani proofs (the
counter after a reboot exceeds every counter before it; never issue above the
durable ceiling; a failed write issues nothing). On silicon, A was unplugged after
sending counters 154–163; it came back at `tx=1279` (ceiling read from flash), sent
counter 1280, and the relay accepted it —
`evidence/silicon/2026-10-06/followup/REPORT.md` test 4.

Limits: up to ~1 279 counters are skipped per reboot in the firmware (it reserves
`tx + 1024` before each command buffer) — harmless; a wiped or re-provisioned
device restarts at 0 and will be refused by relays that remember it; a power cut
*during* a flash write was tested on the PC simulator only; flash endurance is an
estimate (~5 × 10⁷ counters at 100 k cycles × 2 sectors), not a measurement.

---

## 6. Threat model — attack → defence → test that proves it

| # | attack | v0B defence | test (`v0b_*`) |
|---:|---|---|---|
| 1 | 1-bit flip in **any** signed byte (exhaustive) | digest/sig mismatch | `v0b_bitflip_each_signed_byte_rejected` → `"bad mesh signature"` (and §3 cheap reasons for the magic/network/len bytes) |
| 2 | relay swaps payload, keeps sig | `SHA-256(payload)` changes → sig fails; real msg still fresh | `v0b_content_swap_rejected_real_still_passes` |
| 3 | origin spoofed (other key) | registry pubkey ≠ signer | `v0b_forged_origin_rejected` → `"bad mesh signature"` |
| 4 | immediate replay | counter bit set | `v0b_immediate_replay_rejected` → `"replay detected"` |
| 5 | replay **after relay reboot** (state from persistence) | persisted `CounterTracker` | `v0b_replay_after_reboot_rejected` (+ silicon T8) |
| 6 | replay after Bloom reset + dedup overflow | counter window independent of Bloom | `v0b_replay_after_bloom_reset_rejected` |
| 7 | foreign `network_id` | step 2, before signature | `v0b_foreign_network_rejected` → `"foreign network"` |
| 8 | revoked origin | step 3, before signature | `v0b_revoked_origin_rejected` → `"origin revoked"` |
| 9 | `ttl` inflated by relay | clamped to `MAX_TTL`; accept-once is the real bound | `v0b_ttl_inflation_bounded` |
| 10 | invalid msg then the real msg | verify-before-remember: state untouched by the invalid one | `v0b_invalid_then_valid_accepted` |
| 11 | reorder within 127 positions | bitmap gap-fill, accept exactly once | `v0b_reorder_within_window_accept_once` |

### Kani proofs (`src/mesh/kani_proofs.rs`) — 7 added

Pure, tractable properties (no Ed25519/BTreeMap, so Kani can discharge them):
- `proof_v0b_parse_never_panics_full/_short/_with_payload` — the v0B parser never
  panics on arbitrary input (full header, sub-header → `None`, header+payload).
- `proof_v0b_preimage_binds_payload_digest` — distinct payload digests ⇒ distinct
  signed preimages (content bound; SHA-256 collision-resistance assumed, not unrolled).
- `proof_v0b_preimage_binds_counter` — distinct counters ⇒ distinct preimages.
- `proof_v0b_preimage_binds_network` — distinct network ids ⇒ distinct preimages.
- `proof_v0b_preimage_domain_separated_and_consistent` — layout constants are
  consistent and the domain tag always prefixes the signed data.

**Honestly test-covered, not Kani-proven** (they transit Ed25519 + a BTreeMap,
which Kani cannot unroll tractably): verify-before-remember (a rejected message
mutates no state) and window monotonicity are covered by the deterministic unit
tests `v0b_invalid_then_valid_accepted`, the `last_seen == 0` assertions in
`v0b_bitflip_each_signed_byte_rejected`, and `v0b_reorder_within_window_accept_once`.
Per [[reference_kani_wsl_limit]], the full CBMC pass runs in the kani-proofs CI
job / a ≥16 GB Linux host, not on local WSL.

---

## 7. What v0B costs (to be measured, not optimised)

- **No sender anonymity** — `origin_fp` is in clear and must be pre-registered
  (unlike Reticulum, which omits source addresses by design).
- **~176 ms Ed25519 verify per hop on Cortex-M0+** (measured v0A baseline;
  v0B adds one `SHA-256(payload)` over the payload, far cheaper than the sign).
  Measured K=10 on PC and K=5 on chip in Phases 2–3; v0B vs v0A reported side by
  side. Not optimised.
- **Persistence** — one flash-lease write per `L` messages (§5); a small bounded
  counter skip per reboot.

---

## 8. Non-negotiable constraints honoured

- v8/v9/v0A behaviour unchanged; v0B is additive. Existing workspace tests stay
  green (baseline count pinned at the start of Phase 2).
- No homemade crypto: Ed25519 (`ed25519-compact`), SHA-256 (`sha2`) — both already
  dependencies.
- `no_std`: v0B compiles for `thumbv6m-none-eabi` with
  `--no-default-features --features mesh_bloom_mcu,mesh_v10` (new code behind the
  existing `mesh_v10` gate, or a `mesh_v0b` sub-feature if cleaner — decided in
  Phase 2).
- Verify-before-remember (§3 step 7 is the only state writer).
- No number without a raw log; a failing test is written as FAIL + cause; no test
  is ever weakened to pass.

---

## 9. Status (2026-10-06)

Phase-1 decisions, as resolved and built:
1. **Counter lease `L = 256`**. Receiver window in the last 4 KiB flash sector,
   sender ceiling in two alternating sectors; both implemented and silicon-proven
   (T8, then the follow-up's byte-exact replay and sender-reboot tests) — see §5.
2. **Folded into the existing `mesh_v10` cargo feature** (v0B builds on the v0A
   Ed25519 machinery, and this keeps the MCU build command unchanged).
3. **`MAX_TTL = 8`** (`DEFAULT_TTL`).

Delivered: implementation in `oasis-rt/src/mesh.rs`; **11 `v0b_*` tests** (one
per attack in §6) — workspace went 444 → 455 lib tests, 0 failed; **7 Kani
proofs**; cost bench `bench_mesh_v0b` (v0B ≈ v0A + ~1 %); silicon validation on
3 RP2040 boards (`evidence/silicon/2026-10-06/REPORT_MESH_V0B.md`) — 0/150
bit-flips accepted, suppression defeated, T8 passed across a real power-cut.

Follow-up (same day, `evidence/silicon/2026-10-06/followup/`): strict mode on
silicon — 150/150 bit-flips traced, 0 accepted, magic flips always rejected as
legacy; downgrade refused (negative control with `k`); byte-exact replay across a
power-cut of B refused `stale counter`; sender lease across a power-cut of A —
the rebooted origin was accepted.

Open: LoRa/over-the-air (this chain is a wire; SX1262 is still mock-tested only);
receiver-side write coalescing (the chip flushes the window on demand).
