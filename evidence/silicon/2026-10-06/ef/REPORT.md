# Part C on silicon — signed mesh revocation (E) and actuation gate (F)

Prompt: `prompts/OASIS_REVOCATION_GATE_ATTACKSUITE.md`, Part C. Spec:
`docs/REVOCATION_AND_ACTUATION_SPEC.md`. Three RP2040 clone boards on UART0 at
115 200 baud. Firmware `uart_mesh` was built from the **clean, committed and pushed**
tree **`6daa0bc`** (branch `oasis-e-f-attacks`). That stamp is the only one on all
179 log lines in this folder. Logs are LF (0 CR bytes). Hashes in `SHA256SUMS`,
re-verified in a fresh clone after the commit.

Every decision below comes from the same `oasis-rt` code the PC tests exercise
(`mesh_revocation::revocation_transition`, `actuation::actuation_decision`) and
from `oasis-operator-key` for the operator signature. The operator **seed** stays on
the PC (`oasis-operator-key/examples/ef_payloads.rs`); the firmware holds only the
operator public key.

## Role mapping (wiring forces it)

The chain is wired one way: A.TX → B.RX and B.TX → C.RX. C's TX reaches nobody, so
"C emits and B rejects" is physically impossible on this rig. The prompt's roles
were relabelled to prove the same properties without rewiring:

| Prompt | Run here |
|---|---|
| Revoke C; C emits; B rejects at the first hop | Revoke **B**; B emits; **C** rejects at the first hop |
| Power-cut B; B still rejects | Power-cut **C**; C still rejects B |
| C is the actuator; orders from A (authorized) and B (not) | unchanged |
| The operator key (PC) is carried by A | unchanged |

C.4 ran **first**, on clean state. If B had already been revoked, its order would
have died at the v0B layer and never reached the gate's "not authorized" condition.

Start of session: `!` on all three boards (`00_reset.log`) erased the v0B window, the
sender lease and the revocation list, then did a full reset. `K` was sent before each
test, and every board answered `MODE|strict_v0b=true`.

## C.4 — actuation gate (actuator = board C, GP25)

Each command was built on the PC against **C's own clock** (`S` → `boot_id`,
`now_ms`; `40_act_clock.log`), originated by the sender, and relayed A → B → C.
`pin25` is the **pad level read from SIO `gpio_in`**, not the commanded value.

| # | Case | Expected | Obtained (C) | Logs |
|---|---|---|---|---|
| a | Valid order from A (seq 2) | act, LED on | `Act`, `pin25=1` | `42_act_valid_*` |
| — | (first attempt, seq 1) | — | `Reject(Expired)`: my harness used a 4 s validity and ~3.6 s of it was spent in the status read and the crypto path. The gate correctly refused a command whose deadline had passed; the retry used 9 s | `41_act_attempt1_expired_by_harness_latency_*` |
| b | Order from **B** (registered, not an authority) | no action | `Reject(NotAuthorized)`, `pin25=0` | `44_act_from_B_*` |
| c | Expired order (deadline already past on C's clock) | no action | `Reject(Expired)`, `pin25=0` | `45_act_expired_*` |
| d1 | **Byte-for-byte replay** of the executed seq 5 envelope (`z`) | no action | **stopped at the first hop**: B `DROP\|stale counter`; C received no frame (its frame counter goes 5 → 6 across this capture, so the empty C log is a real silence) | `46_…`, `47_replay_bytes_*` |
| d2 | Same command content re-sent | no action | `Reject(Expired)` (the sequence ran past the deadline) | `48_replay_content_*` |
| d3 | Same content re-sent **inside** the deadline | no action | `Reject(StaleOrReplayed)`; `executed` unchanged | `50_…`, `51_seqguard_resend_*` |
| e | Valid order, **sensor lost** (`U`) | no action | `Reject(R14Unsafe)`, on-chip entropy **0.908** (calm: 0.361), `pin25=0` | `53_…`–`55_…` |
| f | Force 1000 N (limit 50 N) | no action | `Reject(OutOfLimits)`, `pin25=0` | `56_out_of_limits_*` |
| g | Force = NaN | no action | `Reject(OutOfLimits)`, `pin25=0` — `hal::clamp_command` alone fails open on NaN; the gate's finiteness check closes it | `57_nan_force_*` |
| h | Valid order again (seq 10) | act | `Act`, `pin25=1` | `58_final_valid_*` |

Totals on C (`59_act_summary_C.log`): **executed = 4** (seq 2, 5, 6, 10 — all
legitimate). Rejects by reason, in order NotVerified / NotAuthorized / Revoked /
Expired / R14Unsafe / OutOfLimits / StaleOrReplayed: `0/1/0/3/1/2/1`.

**LED:** I could only read the pin level back. Whether the LED physically lit was
**not visually confirmed** (asked, no answer). Some clone boards don't wire the
LED to GP25. Also, the `L` (LED off) log line shows `pin25=1`, because the read
lands a few cycles after the write and the input synchroniser lags by ~2 cycles.
Every later read shows `0`.

## C.1 — revocation propagated

| Step | Board | Log line |
|---|---|---|
| PC signs epoch 1 = {B}; A carries it (`kind=ORV1`) | A | `PAYLOAD_TX\|kind=ORV1,counter=12,len=234` |
| verify operator signature → persist → apply → forward once | B | `REV\|decision=Applied,epoch=1,revoked=1,persisted_before_apply=true` + `RELAYED` |
| same | C | `REV\|decision=Applied,epoch=1,revoked=1,persisted_before_apply=true` |
| **B emits** | C | `DROP\|origin revoked` (before its Ed25519 check) |
| control: A emits **through** revoked relay B | C | `ARRIVED…sig=verified` |

Logs `60_…`–`63_…`. The control shows that revocation removes B as an **origin**,
not as a relay: B still forwards other nodes' authenticated traffic. It cannot forge
it, but it could drop or delay it. That limit is noted below.

## C.3 — replay of an old list

Epoch 2 = {B, 0xDD…} was applied on B and C (`64_rev_e2_*`). A then re-sent the
**byte-identical** epoch-1 operator content in a fresh envelope. B answered
`REV|decision=Reject(Rollback)` and did **not** forward it, so C received nothing
(`65_rev_replay_e1_*`). C's own rollback rejection is therefore covered by the PC
test `rev_old_epoch_rejected`, not by this run.

## C.2 — revocation after a real power-cut of C

| Step | Log |
|---|---|
| C unplugged and replugged (USB) | — |
| C after boot: `now_ms=42570, rx_bytes=0, executed=0` (RAM wiped) **and** `epoch=2, revoked=2` | `70_postcut_C_status.log` |
| `boot_id` 0 → **1279** (strictly higher) | same |
| B emits; C's **first frame since boot** (`RXF n=1`) → `DROP\|origin revoked` | `72_postcut_B_emits_*` |

The list can only have come from flash, and `Ef::restore` re-verifies its operator
signature before applying it at boot.

## Extra — `boot_id` binding (spec F.2) after the reboot

A command stamped with C's **previous** `boot_id` (0), whose deadline was numerically
valid on the new clock, gave `Reject(Expired)`. The same command with the new
`boot_id` (1279) gave `Act` (`73_…`–`75_…`). This exercises the forced boot-time
lease reservation added in `6daa0bc`. Without it, two boots could share a
`boot_id`.

## Not shown on silicon (covered on PC only, or not at all)

- **k-of-n** operator quorum: PC only (`oasis-operator-key/tests/mesh_revocation.rs`).
  The silicon run used a single operator key.
- **Catch-up** of a disconnected relay through `OEP1` beacons: PC only
  (`rev_disconnected_relay_catches_up`). The firmware does not implement beacons.
- **C's own rejection of an old list**: B stopped it first (C.3).
- A **torn** flash write during a real power cut was not produced.
- C's **v0B counter window** is still flushed on demand (`P`) only, so after the
  power-cut C's window for A was empty (`a_last_seen=0`). A replayed actuation
  envelope reaching C directly would pass v0B, but the gate would still refuse it as
  `Expired` because of the `boot_id` change. The silicon run did not exercise that
  path: B stops replays first.

## Limits that remain

A revoked node can still relay, drop or delay others' traffic (revocation removes
it as an origin, not as a hop). There is an exposure window before catch-up. A
compromised operator quorum can revoke everyone. There's no secure element: keys
and persisted state are readable and writable over SWD. Still a wire, not a radio.
The Kani harnesses for `mesh_revocation` and `actuation` were written but not run
when this report was produced. **Addendum, same day:** they were then run
individually in WSL and verify (16/16 with the v0B and lease harnesses), after the
revocation harnesses' unwind bound was raised from 4 to 10 (`memcmp` needed ≥ 9);
see `evidence/kani/2026-10-06/`.

## Comparative claim

**None.** Part D (attack suite against Bluetooth Mesh / Reticulum / Meshtastic) is
**deferred pending a simulation environment**, after the owner's 15-minute WSL
timebox expired (`attack-suite/DEFERRED.md`). E and F are proven for OASIS only.
