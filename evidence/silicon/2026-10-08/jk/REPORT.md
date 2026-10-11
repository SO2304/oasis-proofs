# Silicon — phase 2 parts J and K (compact stop, commander clock view)

**2026-10-08, 3× RP2040.** Spec `docs/AUTHORITY_HARDENING_SPEC.md` §J.4 and §K.6.
Firmware stamp **`6d3429f`**, version 25 on B and C, floor 25, `guard_failed_before=0`.

| Board | Role | Firmware |
|---|---|---|
| **A** | brownfield Modbus device, `rmodbus`, **no OASIS code** | `modbus_device`, `a39d5fe` |
| **B** | order origin / commander | `uart_mesh` v25, `6d3429f` |
| **C** | actuator (LED GP25) **and** Modbus gateway | `uart_mesh` v25, `6d3429f` |

> **No claim of functional safety.** See `docs/compliance/IEC_TS_63074.md`.

**Result: part J 6/6, part K 6/6.** Part K needed one wire moved partway through; §2 and §3 record it as it happened, §6 has the completed run.

---

## 1. Part J — the compact stop `OAS1`

| # | Test | Result | Journal |
|---|---|---|---|
| **J4** | `OAS1` from an origin holding `ACTUATE` but **not `STOP`** (attestation seq 10, `perms=1`) | `Reject(NotAuthorized)`, **neither latch set** (`stopped_led=false, stopped_gw=false`) | seq 0, `cmd_seq=400` |
| **J1** | `OAS1` with `actuator_id = 0` | `Stop`, **both latches** (`stopped_led=true, stopped_gw=true`), LED off. 110 bytes on the wire | seq 1, `cmd_seq=401` |
| **J2** | Modbus order while latched | `Reject(Stopped)`, **no frame built** | — |
| **J3** | after `@Zc`, `OAS1` with `actuator_id = 1` | `Stop` with `stopped_led=true`, **`stopped_gw=false`** | seq 2, `cmd_seq=402` |
| **J3** | Modbus order immediately after | **`Act`** — the gateway is still free, as addressed | — |
| **J6** | `OAC1` class `Stop`, the long format | `Stop` — **non-regression holds**, `OAS1` added nothing it took away | seq 3, `cmd_seq=403` |
| **J5** | journal read off flash, verified on the PC | **`VERDICT intact entries=4`, exit 0** | — |

### The device's own count

Board A runs `rmodbus` and no OASIS code.

| Moment | A's `writes` |
|---|---|
| before the campaign | 6 |
| **after the Modbus order sent while both latches were set (J2)** | **6 — unchanged** |
| after the order sent while only the **LED** was latched (J3) | **7** |

So `actuator_id` is not decoration: addressing actuator 1 stopped the LED and left the
gateway working, and the device's own byte counter is what says so.

### The journal

```
boot_id=49629 entries=4 head_seq=Some(3) overwritten=0
  [0] seq=0 cmd_seq=400 class=Stop decision=Reject(NotAuthorized) flags=0x07
  [1] seq=1 cmd_seq=401 class=Stop decision=Stop                  flags=0x0f
  [2] seq=2 cmd_seq=402 class=Stop decision=Stop                  flags=0x0f
  [3] seq=3 cmd_seq=403 class=Stop decision=Stop                  flags=0x0f
VERDICT intact entries=4
```

`cmd_seq` is the field the stop rule does **not** read, kept only so the trace can tell two
stops apart (§J.4). Here it is doing exactly that: 400 refused, 401 fleet-wide, 402
LED-only, 403 in the long format. Without it the four lines would be indistinguishable.

---

## 2. Part K — K1 passed, K2 did not run

| # | Test | Result |
|---|---|---|
| **K1** | B has no view, an order is requested | **`ORDER_REFUSED no_usable_view`** — a commander without a view refuses to build rather than guess |
| K2 | C emits its beacon, B receives it | C emitted it (`TIME_TX boot_id=49629, now_ms=117104, len=119`) and **B never received it** |
| K3–K6 | — | **not reached**: they all need K2 |

## 3. Why K2 did not run, and it is not the code

**The mesh wiring is one-way.** `A.GP0 → B.GP1` and `B.GP0 → C.GP1`: each link carries
bytes in a single direction, downstream. Part K needs the **opposite** direction — the
beacon travels from the actuator (C) to the commander (B).

So C emitted a correct 119-byte signed beacon into a wire that goes nowhere: C's `GP0` is
the end of the chain. Nothing in `TimeView`, in the `OTM1` dispatch or in `content_kind` was
at fault, and B's view stayed empty exactly as `proof_timeview_*` says it should when no
beacon arrives.

**What it takes to finish part K: moving one wire.** Part K needs a bidirectional B↔C link,
and `B.GP0 → C.GP1` already provides one direction. The other needs `C.GP0 → B.GP1` — the
pin `A.GP0` currently occupies. Board A plays no part in K (it is the Modbus device, reached
over UART1, which is untouched), so the wire on `B.GP1` can be moved from `A.GP0` to
`C.GP0`.

**What was NOT done instead, and why.** The beacon could have been relayed to B by the PC
with `@J<hex>`, and B would have verified it as a v0B frame all the same. That would have
exercised `TimeView` and the dispatch — but it would **not** have shown the thing part K
exists to show: that a commander obtains an actuator's clock **without a cable to it**.
Relaying through the PC is precisely the laboratory shortcut C4 complains about, wearing a
different hat. So K is reported as 1 of 6, not as passed by proxy.

## 4. What this run does not show

- **Part K is 1 of 6.** `TimeView` has 8 tests and 4 Kani proofs
  (`evidence/kani/2026-10-08/jk/`), and K1 on silicon. The claim that matters — that the PC
  never reads the actuator's clock — is **still not demonstrated**.
- **J2's LED path was not retested here.** `@Zo` was used and correctly refused for lack of
  a view, so only the Modbus half of J2 ran. The LED half was proved on 2026-10-08 as S2
  (`../hardening/`), with the same latch.
- **No duty cycle is enforced.** The sizes and budget of §J.2 are documented, not applied;
  nothing stops the firmware exceeding 36 s of air time per hour. Regulatory, and open.
- **No radio.** The 110-byte figure is the length of a frame on a **wired UART**. The
  time-on-air numbers that make `OAS1` worth having are **computed**, with the formula
  marked "non vérifié à la source".
- Single runs, not banded. The LED is read back from the pin level, not observed optically.

## 5. Files

`RUN.txt` — run log with the pre-campaign state of all three boards.
`NN_<test>_{A,B,C}.log` — one capture per board per step, LF.
`payloads/*.hex` — every payload sent, byte for byte.
`journal_jk.txt`, `39_j5_verify.txt` — the journal and its verification (exit 0).
`SHA256SUMS` — verified from a fresh clone after the commit.

---

## 6. Part K completed (wire moved, 2026-10-08)

The operator moved the wire on `B.GP1` from `A.GP0` to `C.GP0`, giving a bidirectional
B↔C link. Board A keeps its role unchanged, reached over UART1.

| # | Test | Result |
|---|---|---|
| **K1** | B has no view, an order is requested | **`ORDER_REFUSED no_usable_view`** — a commander without a view refuses to build rather than guess |
| **K2** | C emits its beacon, B receives it | C: `TIME_TX boot_id=49629, len=119`. B: `ARRIVED sig=verified` then **`TIME_VIEW applied=true, origin=a7`** |
| **K3** | **B builds an order from its view** | `ORDER_TX from=view, boot_id=49629, deadline_ms=764238, validity_ms=3000, **view_age_ms=46939**` → C: **`Act`**, LED on |
| **K4** | C reboots; B keeps the stale view and sends | `ORDER_TX from=view, boot_id=49629, view_age_ms=205970` → C (now `boot_id=50908`): **`Reject(Expired)`**, LED off |
| **K5** | C emits a fresh beacon, B refreshes, order again | `TIME_VIEW applied=true, actuator_boot=50908, actuator_now=80275` → `ORDER_TX boot_id=50908` → **`Act`** |
| **K6** | a beacon whose clock does **not** advance (`@Zb` with `now_ms` 60 s behind) | **`TIME_VIEW applied=false`**, the view is **unchanged**, and the next order is still accepted |

### The result part K exists for

In K3 the PC supplied **one number: `3000`**, the validity in milliseconds. It never read
`boot_id`, never read `now_ms`, never computed a deadline. B extrapolated a signed beacon it
had received over the mesh — **46,9 seconds old** — and C accepted the order. That is the
laboratory shortcut of C4 removed, not worked around.

K4 is the other half, and it is the one that makes the mechanism usable rather than
fragile: a view a whole boot out of date produced an order that was **refused**, LED off,
and the refusal is how the commander learns to refresh. Every error direction costs an
order, never an unintended execution.

### A detail that confirms the shape of the proof

In K5 the new boot's `now_ms` is **80 275**, far **smaller** than the stale view's estimate
of 943 188 — a reboot restarts the millisecond counter. `TimeView::apply` accepted it anyway
**because the `boot_id` differs**, which is exactly the case
`proof_timeview_apply_is_monotone_within_a_boot` carves out: monotonic *within* a boot,
replaced outright *across* boots. The silicon and the proof agree on a case that is easy to
get wrong in the other direction.

### What K still does not show

- **The reboot in K4 came from reflashing C to v26, not from a power cut.** It is a real
  reset — `boot_id` 49629 → 50908 — but the cleanest version of K4 would pull the cable.
  The journal's survival across a true power cut is separately proved (`../hardening/` §7).
- **K6 is not a byte-exact replay.** Nothing on this bench can drive B's RX pin from the PC,
  so a captured beacon cannot be re-injected toward B. What K6 does test is the one rule
  `TimeView` adds beyond the mesh layer — a same-boot beacon that does not advance is
  refused — using `@Zb<ms>` to force the clock. A true byte replay is stopped a layer below
  by the v0B counter, proved since phase 1.
- **A.GP0 → B.GP1 is now disconnected**, so the three-hop A→B→C mesh chain is not available
  until the wire is moved back. Nothing in parts J or K needed it.
- **No beacon scheduler.** The rule is "one at boot, then periodically" (§K.4); the firmware
  emits on command. Scheduling belongs to a product, not a bench.
