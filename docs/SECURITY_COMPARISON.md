# Mesh security comparison — OASIS v0B vs Reticulum / Meshtastic / Thread

**Claim:** OASIS mesh v0B verifies origin, content, freshness and network of every
message **at each relay**, and rejects forged/modified/replayed/foreign messages
at the first hop — even after a relay reboot. This doc compares that to three
widely used meshes.

## Evidence policy (read this first)

- **OASIS cells** are backed by a test or log I produced in this repo and can
  reproduce: the `v0b_*` tests in [oasis-rt/src/mesh/tests.rs](../oasis-rt/src/mesh/tests.rs),
  the Kani proofs in [oasis-rt/src/mesh/kani_proofs.rs](../oasis-rt/src/mesh/kani_proofs.rs),
  and (Phase 3) the silicon logs under `evidence/silicon/`.
- **Reticulum cells marked Verified** were checked against `markqvist/Reticulum` commit `e40191b` (2026-10-06 review). **Other competitor cells** summarise behaviour from the sources cited in
  `prompts/MESH_V0B_SECURITY.md`. I have **not** independently checked those
  repositories in this session, so each is marked **[non vérifié]** — the
  citation is the prompt author's, not mine. Where I rely only on general
  protocol knowledge I write **[général, non vérifié]**. Treat competitor rows
  as "to confirm against their source", not as established fact.

## Scenario matrix

| Attack | OASIS v0B | Reticulum | Meshtastic | Thread |
|---|---|---|---|---|
| **Payload modified in flight** | Rejected at every relay — payload is bound via `SHA-256(payload)` in the Ed25519-signed data. Test `v0b_content_swap_rejected_real_still_passes`, Kani `proof_v0b_preimage_binds_payload_digest`. | Relays don't crypto-check data packets; integrity only end-to-end. **Verified** in `RNS/Transport.py` l.2018-2045 (commit `e40191b`): forward on path table, hop count and transport id only | Channel AES-CTR gives confidentiality; integrity/auth of broadcast content not per-hop verified **[non vérifié]** | Network-key MIC gives link integrity to anyone holding the shared key **[général, non vérifié]** |
| **Message suppression (keep sig, swap content, poison dedup)** | Defeated: forged content fails the signature *before* any dedup/counter state is touched, so the real message still arrives. Test `v0b_content_swap_rejected_real_still_passes`. | N/A in the same form (no per-packet sig to keep) but no per-hop content auth either **[non vérifié]** | **[non vérifié]** | **[non vérifié]** |
| **Forged origin (signed with another key)** | Rejected — relay looks up the claimed origin's registered Ed25519 key. Test `v0b_forged_origin_rejected`. | Announces are validated; data packets have no source address by design **[non vérifié: validate_announce]** | DMs/admin signed since 2.5, verified at destination not per-hop **[non vérifié]** | Any network-key holder is "authentic" to the link **[général, non vérifié]** |
| **Immediate replay** | Rejected by the per-origin counter window. Test `v0b_immediate_replay_rejected`. | Packet-hash dedup list, up to 1 M entries (`hashlist_maxsize`, Transport.py l.247). It is a list of hashes, not a signed counter. **Verified** | **[non vérifié]** | Frame counter **[général, non vérifié]** |
| **Replay after relay reboot** | Rejected — counter high-water mark is **persisted** and restored on boot. Test `v0b_replay_after_reboot_rejected` (+ Phase 3 silicon T8). | **Persisted:** the packet-hash list is saved to storage and reloaded at start (`Transport.py` l.339-343, `save_packet_hashlist` l.3745-3769). Entries not yet saved at an abrupt power loss may be lost; the save schedule was not checked. Unlike OASIS, nothing binds freshness into a signature a relay can verify. **Verified (code)** | **[non vérifié]** | Depends on counter persistence **[général, non vérifié]** |
| **Replay after dedup-cache reset/overflow** | Rejected — the counter window is independent of the RAM Bloom. Test `v0b_replay_after_bloom_reset_rejected`. | Bounded hash list (1 M entries, rotated in halves, l.832-833): a packet older than the retained list can be replayed **(code read; not tested)** | **[non vérifié]** | **[général, non vérifié]** |
| **Message from another network** | Rejected before signature — `network_id` filter + the id is in the signed data. Test `v0b_foreign_network_rejected`. | Network segregation differs (no signed network id per packet) **[non vérifié]** | Different channel key ⇒ undecryptable, but relayed first **[non vérifié]** | Different network key **[général, non vérifié]** |
| **Revoked node** | Rejected at the first hop, before signature. Test `v0b_revoked_origin_rejected`. | **[non vérifié]** | **[non vérifié]** | Rekey the whole network **[général, non vérifié]** |
| **TTL/hops tampering** | Bounded on receipt (`ttl, hops, ttl+hops ≤ MAX_TTL`); hard anti-amplification is accept-once via the signed counter, not ttl. Test `v0b_ttl_inflation_bounded`. | Hop limit enforced; unsigned **[non vérifié]** | Hop limit; unsigned **[non vérifié]** | Mesh-local hop limits **[général, non vérifié]** |
| **Invalid-then-valid (state pollution)** | Verify-before-remember: a rejected message mutates no state. Test `v0b_invalid_then_valid_accepted`; Kani `proof_v0b_parse_never_panics_*`. | **[non vérifié]** | **[non vérifié]** | **[non vérifié]** |
| **Reorder within window** | Accepted exactly once (128-bit window). Test `v0b_reorder_within_window_accept_once`. | **[non vérifié]** | **[non vérifié]** | **[général, non vérifié]** |

## What OASIS pays for this

- **No sender anonymity.** `origin_fp` is in clear and every origin must be
  pre-registered (an Ed25519 pubkey per node). Reticulum deliberately omits
  source addresses for anonymity; OASIS makes the opposite trade.
- **~176 ms Ed25519 verify per hop on Cortex-M0+** (v0A silicon baseline;
  v0B adds one SHA-256 of the payload — see the PC bench `bench_mesh_v0b` and
  Phase 3 on-chip numbers). v0B is for low-frequency authenticated broadcasts,
  not kHz control loops — v9 HMAC remains the choice for high-rate intra-swarm
  traffic.
- **Persistence cost.** A per-origin counter high-water mark must survive reboot
  (flash-lease strategy, see MESH_V0B_SPEC.md §5).

## Cost numbers

**PC (K=10, median ± half-spread)** — raw log:
`evidence/mesh_v0b/2026-10-06/bench_mesh_v0b.log` (Windows laptop, release):

| op | v0A | v0B | delta |
|---|---:|---:|---:|
| origin_wrap (sign), 15 B | 250 058 ns ±4.3% | 251 596 ns ±25% | +0.6% |
| verify, 15 B | 122 945 ns ±2.0% | 125 585 ns ±1.3% | +2.1% |
| origin_wrap (sign), 1 KB | 250 542 ns ±1.7% | 250 915 ns ±2.7% | +0.1% |
| verify, 1 KB | 125 744 ns ±4.4% | 127 414 ns ±2.1% | +1.3% |

v0B costs essentially the same as v0A: Ed25519 dominates, and binding the
payload adds only one SHA-256 (~2-3 µs, ≈1%), flat even at 1 KB. **Security was
bought at ~1% of the per-message crypto cost, not a redesign of the hot path.**

**On-chip (3× RP2040 Cortex-M0+, K=5 medians)** — raw log:
`evidence/silicon/2026-10-06/v0b_timing_A.log`, firmware stamp `d285ef4`:

| op | v0A | v0B | delta |
|---|---:|---:|---:|
| sign (cached keypair) | ≈173.7 ms | ≈175.5 ms | **+1.0 %** |
| verify | ≈177.9 ms | ≈179.1 ms | **+0.7 %** |

So the per-hop price of binding content+counter+network is ~1 % on top of
Ed25519, on both PC and silicon. **~179 ms verify per hop on an M0+** is the
real cost of the security model — v0B is for low-rate authenticated broadcasts,
not control loops (v9 HMAC remains the high-rate choice).

### Silicon validation of the matrix rows above

Verified on three wired RP2040 boards (A→B→C), full write-up in
`evidence/silicon/2026-10-06/REPORT_MESH_V0B.md`:

- **Payload modified in flight** — 3×50 pre-CRC single-bit flips: **0/150
  accepted** (v0A accepted 12/50 on 2026-10-04).
- **Message suppression** — forged-content copy with the original signature is
  dropped (`bad mesh signature`) and the real message still reaches C.
- **Replay after relay power loss** — relay's counter window restored from flash
  after a physical USB power-cut; the old counter is refused `stale counter`.

**Downgrade (fixed and silicon-verified 2026-10-06):** a v0B router used to
accept v8/v9/v0A; it is now strict by default
(`v0b_strict_router_rejects_legacy_downgrade`). On silicon a strict relay refused a
v0A envelope and accepted it only after `k` (negative control); in strict mode
150/150 bit-flipped packets were traced and 0 accepted —
`evidence/silicon/2026-10-06/followup/REPORT.md`.

**Byte-exact replay across a relay power-cut:** the captured envelope, re-sent
byte for byte after the relay was unplugged, was refused `stale counter` from the
flash-restored window.

**Sender reboot (liveness gap closed):** with the sender counter lease
(`oasis_rt::tx_lease`) an origin unplugged mid-session resumed above its persisted
ceiling (counter 1280 after 163) and the relay accepted it. Before the lease it
restarted at 1 and was refused. Limits: a wiped or re-provisioned device restarts
at 0; endurance is estimated, not measured.

## Revocation (E) and actuation gate (F) — OASIS only (2026-10-06)

Measured on OASIS; **no competitor was attacked**. The comparative attack suite
(Part D of `prompts/OASIS_REVOCATION_GATE_ATTACKSUITE.md`) is **deferred pending a
simulation environment** after the owner's 15-minute WSL timebox
(`attack-suite/DEFERRED.md`), so every competitor column above stays as read from
their code or documentation.

| Attack | OASIS result | Evidence |
|---|---|---|
| Revocation signed by a non-operator key | rejected, state unchanged | `rev_wrong_key_rejected_state_unchanged` |
| Old list replayed (lower or equal epoch) | rejected; silicon: `Rollback` at the first relay, never forwarded | `rev_old_epoch_rejected`; `evidence/silicon/2026-10-06/ef/65_*` |
| Revoked origin keeps emitting | dropped at the first relay **before** its signature check | `rev_then_revoked_origin_dropped_before_signature`; `ef/62_*` |
| Same, after the relay loses power | still dropped; list re-read from flash and re-verified at boot | `rev_persisted_across_reboot`; `ef/70_*`, `ef/72_*` |
| Revoked node broadcasts a "counter-revocation" | dropped (revoked origin), and `BadOperatorSig` if anyone re-carries it | `rev_counter_revocation_by_revoked_node_rejected` |
| Relay offline during the broadcast | catches up through epoch beacons (PC only) | `rev_disconnected_relay_catches_up` |
| k-of-n quorum (k−1, duplicate, outsider signers) | rejected; k distinct members accepted (PC only) | `oasis-operator-key/tests/mesh_revocation.rs` |
| Order from a registered but unauthorized node | no action | `act_unauthorized_origin`; `ef/44_*` |
| Expired order / order stamped for a previous boot | no action | `act_expired`, `act_wrong_boot_id`; `ef/45_*`, `ef/74_*` |
| Byte-exact replay of an executed order | stopped by v0B at the first relay | `ef/47_*` |
| Re-sent order content (same `cmd_seq`) | no action (`StaleOrReplayed`) | `act_replayed`; `ef/51_*` |
| Valid order with R14 unfavourable (sensor lost) | no action (on-chip entropy 0.908) | `act_r14_unsafe_sensor_loss`; `ef/54_*` |
| Over-limit or NaN setpoint | no action — `hal::clamp_command` alone fails open on NaN; the gate checks finiteness first | `act_out_of_limits`, `act_nan_setpoint_rejected`; `ef/56_*`, `ef/57_*` |

What it costs: a revoked node can still relay, drop or delay others' traffic; there
is an exposure window before catch-up; a compromised operator quorum can revoke
everyone; the E/F Kani harnesses verify (16/16 with the lease and v0B ones, `evidence/kani/2026-10-06/`), but the full 129-harness pass is only run by CI.
