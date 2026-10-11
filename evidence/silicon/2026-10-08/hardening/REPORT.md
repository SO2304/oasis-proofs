# Silicon — phase 2 parts G, H, I (stop asymmetry, supervision, journal)

**2026-10-08, 3× RP2040.** Spec `docs/AUTHORITY_HARDENING_SPEC.md` §4. Firmware stamp
**`a09781e`**, version 24 on B and C, floor 24, `guard_failed_before=0` on both.

| Board | Role | Firmware | Fingerprint |
|---|---|---|---|
| **A** | brownfield Modbus device, `rmodbus`, **no OASIS code** | `modbus_device`, stamp `a39d5fe` | `822460d254200275` |
| **B** | order origin | `uart_mesh` v24, `a09781e` | `f6bd34440030a136` |
| **C** | actuator (LED GP25) **and** Modbus gateway | `uart_mesh` v24, `a09781e` | `a7089677a10b7fb0` |

Wiring: mesh `B.GP0 → C.GP1`; Modbus `C.GP4 → A.GP5`, `A.GP4 → C.GP5` (TTL, 19200 8E1).
Owner **o2** (`owner_ed=5b8649c0cfcdbe78`). B enrolled at `enroll_seq` 9 with
`perms=7` = `ACTUATE | STOP | SUPERVISE`, by an owner-signed `OAU1` kind 2 applied on C
through `@L` — the same gate a mesh-received message goes through, since USB is not a
privileged channel.

> **No claim of functional safety.** Nothing here is a certified safety function: no PL
> under ISO 13849-1, no SIL under IEC 62061. The network stop is **not** an emergency stop
> — ISO 13850:2015 4.1.1.3 makes that a complementary protective measure on its own
> dedicated circuit, which OASIS cannot reach. See `docs/compliance/IEC_TS_63074.md`.

---

## 1. Results

All decisions are C's own log lines; the journal column is the entry C persisted for that
decision.

| # | Test | Result | Journal |
|---|---|---|---|
| S0 | valid `Act`, `cmd_seq` 10 | `Act`, **LED on** (`pin25=1`) | seq 0 `Act` |
| **S1a** | **stop with `cmd_seq` 1** — below the executed 10, so `StaleOrReplayed` as an act | **`Stop`**, LED off | seq 1 `Stop` |
| **S1b** | **stop stamped `boot_id - 1`** — `Expired` as an act | **`Stop`** | seq 2 `Stop` |
| **S1c** | **stop while the sensor is reported lost** — `R14Unsafe` as an act | **`Stop`** | seq 3 `Stop` |
| S2 | valid `Act` while the stop is latched | `Reject(Stopped)`, LED off | seq 4 `Reject(Stopped)` |
| S2 | **Modbus order** while the stop is latched | `Reject(Stopped)`, **no frame built** | — |
| S3 | `@Zc` local clear | `was_stopped_led=true, was_stopped_gw=true` → both false | — |
| S3 | the same `Act`, then the same Modbus order | `Act` (LED on), `Act` (frame sent, device acked) | seq 5 `Act` |
| S4a | **stop with a forged signature** (`forge-v0b`, random key claiming B's fp) | `DROP bad mesh signature` — refused at the v0B layer, the gate never runs | — |
| S4b | stop from an origin holding **`ACTUATE` only** (attestation seq 8, `perms=1`) | `Reject(NotAuthorized)`, **no latch** (`stopped=false`) | seq 6 `Reject(NotAuthorized)` |
| S5 | `Act` with supervision required and **no beacon** | `Reject(SupervisionLost)` | seq 7 `Reject(SupervisionLost)` |
| **S5** | **stop with supervision dead** | **`Stop`** — part H does not undo part G | seq 8 `Stop` |
| S5 | beacon `OSB1` seq 1, validity 60 s | `applied=true, boot_match=true` | — |
| S5 | the same `Act` with a live beacon | `Act`, LED on | seq 9 `Act` |
| S6 | **beacon replay** (same `beacon_seq`) | `applied=false` | — |
| S6 | beacon stamped `boot_id - 1` | `applied=false, boot_match=false` | — |
| **S7** | journal read off flash (`@Zd`) and verified on the PC | **`VERDICT intact entries=10`, exit 0** | — |
| **S9** | **one bit flipped** in stored entry 3, byte 20 (`@Zt03,14`) | **`VERDICT broken`, exit 1** | — |
| S10 | non-regression: a valid Modbus order after everything | `Act`, frame sent, device acked | — |
| **S8** | **real power cut** of board C | **entries survived, chain closes against the pre-cut head, exit 0** — see §7 | seq 0–3 re-read |

## 2. The device's own count, which is the only count that matters

Board A runs `rmodbus` and no OASIS code. It counts every byte on its bus.

| Moment | A's `writes` |
|---|---|
| before the campaign | 4 |
| **after the Modbus order sent while the stop was latched** | **4 — unchanged** |
| after the same order following the local clear | 5 |
| after the S10 non-regression order | 6 |

C's gateway agrees: `executed=2, sent=2, ack=2`, and `rejects[7] = 1` — exactly one order
refused for `Stopped`. **Two `Act` decisions, two frames, two writes. The refusal put
nothing on the wire.**

## 3. The journal reconstructs the campaign

`oasis_journal_verify` on the dump, exit 0:

```
boot_id=47071 entries=10 head_seq=Some(9) overwritten=0
  [0] seq=0 cmd_seq=10 class=Act  decision=Act                       flags=0x07
  [1] seq=1 cmd_seq=1  class=Stop decision=Stop                      flags=0x0f
  [2] seq=2 cmd_seq=2  class=Stop decision=Stop                      flags=0x0f
  [3] seq=3 cmd_seq=3  class=Stop decision=Stop                      flags=0x0f
  [4] seq=4 cmd_seq=11 class=Act  decision=Reject(Stopped)           flags=0x0f
  [5] seq=5 cmd_seq=12 class=Act  decision=Act                       flags=0x07
  [6] seq=6 cmd_seq=31 class=Stop decision=Reject(NotAuthorized)     flags=0x07
  [7] seq=7 cmd_seq=40 class=Act  decision=Reject(SupervisionLost)   flags=0x03
  [8] seq=8 cmd_seq=41 class=Stop decision=Stop                      flags=0x0b
  [9] seq=9 cmd_seq=42 class=Act  decision=Act                       flags=0x07
VERDICT intact entries=10
```

Flags: `0x01` sensor state ok, `0x02` within limits, `0x04` supervision live, `0x08`
stopped. Entry 7 shows `0x03` — supervision not live — and entry 8 shows `0x0b`: stopped,
with supervision still dead, and the stop accepted anyway.

**Refusals are recorded, not only executions.** Annexe III 1.1.9, dernier alinéa: « la
preuve d'une intervention légitime **ou illégitime** ». Four of the ten entries are
refusals.

⚠️ On S9 the verdict is `broken at=9` while the tampered entry is 3. That is the
documented limit, not a defect: a **single-head** hash chain detects a modification but
**cannot localise** it, because every hash after the altered entry differs. A *deletion*
is localised, by the `seq` hole. The spec row and the tool's documentation say so.

---

## 4. Four defects of mine, found by this campaign

Each cost a flash cycle or an hour, and each is in the code now with the reason written
next to it.

**1. One latch, two actuators** (`13a3b5c`). C hosts the LED *and* the Modbus gateway, each
with its own `Actuator`. The first integration latched only the LED, so under test S2 the
gateway answered `Act`, built a frame and **wrote to the device while a stop was latched**
— A's counter went up. An operator who stops a machine does not mean "stop one of its
actuators".

**2. The flag was set and ignored** (`13a3b5c`). The first fix set `gw.act.stopped`, but
`gateway_decision` called `actuation_decision` — the context-free entry point, which
substitutes a permissive `GateContext` — so the pure rule never read the latch.
`gateway_decision_ctx` now takes the context, and two tests assert `frame.is_none()`
rather than only the decision, because the frame is the only thing that reaches the device.

**3. `content_kind` did not know `OSB1`** (`a09781e`). The beacon arrived, its signature
verified, and it was **relayed instead of consumed**: the kind string came from a list
parallel to the dispatch, and the missing entry made the `"OSB1"` arm unreachable. Silent,
and silent in the way that looks like the feature working. Caught by S5, where the beacon
changed nothing and the next `Act` was refused again.

**4. A log line before the main loop boot-looped a board into BOOTSEL** (`c171281`). I
logged the journal state right after opening it — before the image confirms itself and
before the watchdog is fed. `Io::log` spins waiting for a USB reader, so with nobody
draining the port the 8 s watchdog fired three boots in a row and the bootloader parked
board C in BOOTSEL, exactly as phase 1.3 designed it to.

That one produced three wrong diagnoses before the right one, and the wrong ones are worth
recording because each looked convincing:
- *"the v17 image is broken"* — v16 booted and v17 did not, three times; but v16 later
  went to BOOTSEL too. The variable was whether I happened to be reading the port.
- *"RP2040-E14, the image is not sector-padded"* — true (both images ended mid-sector, and
  `uf2pad.py` is kept because the erratum is real) but not the cause.
- *"the bootloader state claims a pending swap"* — writing an erased state sector changed
  nothing.

The hypothesis was settled the only way that counts: flash, then wait **40 s without
opening the port** — more than three watchdog cycles. The board stayed enumerated and no
BOOTSEL volume appeared. It is the same defect the phase 2.1 report already recorded for
the per-frame log, reintroduced at boot time where it is worse: a run-time stall loses
data, a boot-time stall parks the board.

**A fifth, in the harness rather than the firmware:** `send_read.sh` spun on a bad file
descriptor when a port disappeared and emitted 61 MB of errors in seconds. It now fails
fast. And an early "all three boards are silent" scare was `| head -3` killing the reader
with SIGPIPE before the replies arrived — the boards were fine.

## 5. What this run does not show

- **S8, the power cut, was not run.** So the claim "at most one unconfirmed entry across a
  power cut" is **designed and unit-tested, not demonstrated on silicon**. It is the one
  test in §4 that needs a hand on the cable.
- **A revoked origin refusing a stop** was not run. It is the single documented exception
  to `proof_stop_never_blocked`, and revocation is **permanent**: testing it would revoke
  B and end the campaign. Deferred until after S8.
- **The journal ring never wrapped.** 10 entries of 64 slots; the `overwritten` counter
  stayed at 0, so the reclaim path is unexercised on silicon.
- **The journal is tamper-evident against a remote attacker only.** BOOTSEL and SWD rewrite
  entries and head together — `@Zt` itself is proof that local flash writes are possible.
  The signed external anchor is specified and not built.
- Single runs, not banded. One wired link, no radio. The LED is read back from the pin
  level, not observed optically.
- `@Zd` reports `prev_boot` from the **boot-time** open, so after a `@Zw` wipe that field
  is stale (it read `Some(45792)` here, from the run before the reflash). Cosmetic, in the
  harness.

## 6. Files

`RUN.txt` — run log with the pre-campaign state of all three boards.
`NN_<test>_{A,B,C}.log` — one capture per board per step, LF.
`payloads/*.hex` — every payload sent, byte for byte.
`journal_dump.txt`, `43_s7_verify.txt` — the journal and its verification (exit 0).
`journal_dump_tampered.txt`, `46_s9_verify_tampered.txt` — after one flipped bit (exit 1).
`SHA256SUMS` — verified from a fresh clone after the commit.

---

## 7. S8 — real power cut (added 2026-10-08, after the operator pulled the cable)

Board C's USB cable was **physically unplugged and plugged back in**. Four decisions had
been written first, and the head captured before the cut.

| Step | Observed |
|---|---|
| before the cut | 4 entries, head `seq=3`, hash `ac457857…`, **verified intact, exit 0** |
| after the cut | `boot_id` **47071 → 48350** — a real reboot, not a reset of the counter |
| | **4 entries still in flash**; the stored head was read back, recognised as another boot's (`restored=false, prev_boot=Some(47071)`) and a **fresh chain** started for 48350 |
| **the decisive check** | the 4 surviving entries verified against the **pre-cut head**: **`VERDICT intact entries=4`, exit 0** — byte-identical decisions, including the two refusals |
| one new decision in the new boot | `Act`, journal `seq=0` of the new chain, written **after** the old entries in the ring |
| both chains afterwards | new boot 48350: 1 entry, **intact**. Old boot 47071: 4 entries, **still intact** |

So the journal survives a power cut, the previous boot's chain stays verifiable **after**
the new boot has written to the same ring, and the `boot_id` carried in every entry is what
makes the two separable.

### What S8 does and does not establish

- **Established**: persistence across a real power cut; no entry lost; no entry altered;
  the chain closes against a head held by the operator; the ring continues without
  corrupting the previous boot.
- **Not established**: the "**at most one unconfirmed entry**" case. That needs the cut to
  land inside the ~200 ms window between programming the entry page and committing the
  head. The cut here fell outside it, so the `Unconfirmed` verdict remains **designed and
  unit-tested** (`jrn_power_cut_leaves_one_unconfirmed_entry`), **not demonstrated on
  silicon**. Hitting that window by hand is not realistic; it would need a switched supply
  triggered on the write.
- **A property this made explicit**: the board does **not** re-verify the previous boot's
  journal itself. The operator does, with the head they already hold. That is the external
  anchor of §I.5 in miniature — and it is also why the anchor matters: without a head held
  off the board, a local attacker could rewrite entries and head together.

Files: `50_s8_wipe_C.log` … `62_s8_verify_oldboot_again.txt`, with
`journal_precut.txt`, `journal_postcut_vs_precut_head.txt`, `journal_newboot.txt`,
`journal_oldboot_after_newentry.txt`.

**Campaign total: 19 of 20 tests run and passed.** The one left is the revoked-origin
stop — the single documented exception to `proof_stop_never_blocked` — deliberately not
run, because revocation is permanent and would end the campaign on these boards.
