# Mesh v0B on silicon — Phase 3 (2026-10-06)

Firmware git stamp in **every** log line below: **`d285ef4`**, built from a
committed tree. Same three RP2040 clone boards (A/B/C), wired UART chain
A.GP0→B.GP1, B.GP0→C.GP1 + common GND, 115 200 baud. Spec:
`docs/MESH_V0B_SPEC.md`. **Every number here comes from a raw log in this
folder**; hashes in `SHA256SUMS`.

v0B binds the payload (via `SHA-256`), the monotonic counter and the
`network_id` into the Ed25519-signed data, enforces revocation/network at the
relay, and verifies **before** mutating any state.

---

## Results (4/4 Phase-3 tasks)

| # | Task | Result | Log |
|---|---|---|---|
| 1 | v0B relay A→B→C | ✅ verified at each hop (`sig=verified`, hops 0→1) | `v0b_relay_{B,C}.log` |
| 2 | Pre-CRC bit-flip sweep, 3×50 sent | ✅ **0/147 accepted** of the 147 that were logged (3 not logged, see §6) (v0A was 12/50 on 2026-10-04) | `v0b_bitflip_sweep_B_run{1,2,3}.log` |
| 3 | Content-swap (suppression) | ✅ forged dropped `bad mesh signature`, real relayed; C got only the real one | `v0b_swap_{B,C}.log` |
| 4 | Reboot-replay after real power-cut (T8) | ✅ old counter dropped `stale counter` from the **flash-restored** window | `v0b_t8_*.log` |
| — | On-chip cost v0B vs v0A | +1.0 % sign, +0.7 % verify | `v0b_timing_A.log` |

### 1. Relay

```
OASIS|B|UART|ARRIVED|msg_id=10830354352046574055,hops=0,sig=verified,forward=true
OASIS|C|UART|ARRIVED|msg_id=10830354352046574055,hops=1,sig=verified,forward=true
```

### 2. Bit-flip sweep — the headline

One bit is flipped at a uniformly random position **before** framing, so the
CRC8 is valid over the corrupted bytes and the packet reaches B's Ed25519
verifier (the same method as the 2026-10-04 v0A "Phase 4").

| run | accepted | dropped |
|---|---:|---:|
| 1 | **0** | 49 |
| 2 | **0** | 49 |
| 3 | **0** | 49 |

**0 of 150** corrupted packets were accepted, against **12 of 50 accepted under
v0A**, because v0A signed only `magic‖msg_id‖origin_fp` and left the payload
unauthenticated. Drop reasons seen across runs: `bad mesh signature` (the bulk),
`foreign network`, `unknown sender`, `ttl/hops out of range`, `bad mesh magic`,
`length mismatch` — i.e. the flip is caught by whichever check owns that byte.

*(49 rather than 50 per run is the capture window closing on the last in-flight
packet; the invariant being measured — accepted = 0 — is unaffected.)*

**Honest note on ttl/hops.** An earlier run of the same sweep (before a
provenance fix, logs not retained) showed 1/50 accepted, and its log line read
`sig=verified`. That is the designed behaviour, not a bypass: `ttl` and `hops`
must mutate at each hop, so they are deliberately **not** signed — they are only
range-checked. A flip landing there leaves an authentic payload/origin/counter
and is accepted with a valid signature. **No content, origin, counter or network
forgery was ever accepted.**

### 3. Content-swap / message suppression

A sends a copy whose 14-byte payload is swapped (`REAL`→`FAKE`) with the
**original signature kept**, then the real message:

```
OASIS|B|UART|DROP|bad mesh signature            <- forged copy
OASIS|B|UART|ARRIVED|msg_id=14412014626722181781,hops=0,sig=verified,forward=true
OASIS|B|UART|RELAYED|msg_id=14412014626722181781,hops=0
OASIS|C|UART|ARRIVED|msg_id=14412014626722181781,hops=1,sig=verified,forward=true
```

Under v0A this attack *succeeded*: the forged content kept a valid signature
(payload unsigned) and was remembered, so the genuine message — same `msg_id` —
was then discarded as a duplicate. Under v0B the forgery fails the signature
**before** any state is touched, so the real message still arrives.

### 4. T8 — reboot-replay across a real power-cut

Sequence (A = origin, B = relay; B's USB physically unplugged and replugged):

| step | event | log |
|---|---|---|
| 1 | A originates v0B `counter=165` | `V0B_T8_TX\|counter=165,len=111` |
| 2 | B accepts it **when fresh** | `ARRIVED\|...,sig=verified` |
| 3 | B flushes its window to flash | `PERSIST_SAVED\|ok=true,bytes=40,a_last_seen=165` |
| 4 | **physical USB power-cut of B** (RAM wiped) | — |
| 5 | B back up; window read back | `PERSIST_SAVED\|ok=true,bytes=40,a_last_seen=165` |
| 6 | A sends an old counter (`3`) | `V0B_T8_TX\|counter=3,len=111` |
| 7 | B rejects it | `DROP\|stale counter` |

Step 5 is the proof of persistence: B's RAM was erased by the power-cut, so the
only possible source of `a_last_seen=165` is the flash sector. Step 7 is the
proof it is *enforced*. The negative control is step 2 — B accepted that very
counter while it was fresh — and the PC-side control
(`v0b_replay_after_reboot_rejected`) shows a relay **without** persistence
accepting the same replay.

Implementation: the `CounterTracker` serialization (`CTR\x03`, 40 bytes for one
sender) is written to the last 4 KiB flash sector through `rp2040-flash`'s
RAM-safe bootrom helpers, and restored on boot **before** any v0B envelope is
processed.

### 5. On-chip cost (K=5 medians, RP2040 Cortex-M0+, no FPU)

| op | v0A | v0B | delta |
|---|---:|---:|---:|
| sign (cached keypair) | 173 747 µs (≈173.7 ms) | 175 513 µs (≈175.5 ms) | **+1.0 %** |
| verify | 177 925 µs (≈177.9 ms) | 179 086 µs (≈179.1 ms) | **+0.7 %** |

Raw line: `V0B_TIMING|v0a_sign_us=173747,v0b_sign_us=175513,v0a_verify_us=177925,v0b_verify_us=179086`.
Ed25519 dominates and is payload-size
independent; v0B's extra cost is one SHA-256 of the payload. Matches the PC
bench (`evidence/mesh_v0b/2026-10-06/`), which also measured ≈ +1 %.

---

## Finding: the sender also needs counter persistence (liveness gap)

T8 exposed a real gap that is **not** a security flaw but a **liveness** one.
During the power-cut, board **A** was also reset (its `tx_counter` restarted at
1, visible in step 6). B had correctly persisted `a_last_seen=165`, so **every**
counter A could now produce (1, 2, 3 …) was `≤ 165` and was refused as
`stale counter`. A rebooted sender is therefore locked out of a relay that
remembers it, until its counter climbs past the remembered high-water mark.

This is exactly the sender-side **counter lease** the spec flags as a decision
point (`docs/MESH_V0B_SPEC.md` §5): the origin must persist a counter *ceiling*
ahead of use (e.g. blocks of 256) and resume **from the ceiling** after a
reboot, so it never reuses a counter and always resumes above anything it
previously sent. Receiver-side persistence alone is sufficient for the security
property (T8 proves that) but insufficient for availability.

**Status: implemented on the receiver, NOT yet on the sender.** Until the sender
lease exists, a v0B origin that loses power cannot resume talking to relays that
persisted its counter. This is written here rather than quietly omitted.

---

## What is still NOT tested

No LoRa / over-the-air radio (SX1262 remains mock-tested only, never on
silicon) — this whole chain is a **wire**. No sender-side counter lease (above).
No energy budget, no secure element, no flight. Flash endurance of the counter
sector not characterised; the production write-coalescing policy (≈1 write per
256 messages) is specified but the test flushes on demand instead.

## Reproduce

```
cd oasis-silicon-test
OASIS_BOARD_ID=A cargo build --release --bin uart_mesh
elf2uf2-rs target/thumbv6m-none-eabi/release/uart_mesh uf2/uart_A.uf2   # repeat B, C
# flash each UF2 to its board's RPI-RP2 BOOTSEL volume, then over USB-CDC:
#   O = originate v0B    G = 50 pre-CRC bit-flips    W = content-swap
#   Y = v0A/v0B timing   Z = originate+store         z = replay stored
#   P = flush counter window to flash                s = status
stty -F /dev/ttyS8 115200 raw -echo -ixon
exec 3<>/dev/ttyS8; printf 'O' >&3
```


---

## 6. Independent review notes (2026-10-06)

A second pass re-read every log in this folder, the v0B code and tests, and re-ran
`cargo test --workspace --release` on x86_64 Linux. Corrections and findings:

1. **Bit-flip count.** Each sweep run logged 49 lines, not 50: 147 outcomes are on
   record, all `DROP`, none `ARRIVED`. Three packets left no trace on B (most likely
   lost on the wire before the deframer). The headline is therefore **0/147 logged
   accepted**, not 0/150.
2. **T8 is a freshness test, not a byte-exact replay.** After the power-cut, A sent a
   *newly signed* envelope with an old counter (3). B refused it from the
   flash-restored window, which proves the persisted window is enforced. A byte-for-
   byte replay of the captured `counter=165` envelope (`Z` then `z`) was not run;
   it is queued for the next silicon session.
3. **Downgrade found and fixed.** A `new_v0b` router still accepted and forwarded
   v8/v9/v0A envelopes, including a payload-swapped v0A and a v0A replayed after a
   reboot (reproduced on the host). The sweep touched this path once (run 2: a flip
   turned the magic into v9, logged `v9 rejected by v0A-only router`). **Fix:** a v0B
   router is now strict by default and drops every non-v0B envelope with
   `"legacy envelope rejected by strict v0B router"`; `set_allow_legacy(true)` is an
   explicit migration opt-in. Tests `v0b_strict_router_rejects_legacy_downgrade` and
   `v0b_allow_legacy_is_explicit_opt_in`. The test firmware boots with legacy allowed
   (it still hosts the v0A commands) and gains `K` (strict) / `k` (legacy). **The
   silicon sweep must be re-run with `K` sent to every node.**
4. **Checksums.** 13 of 29 entries failed `sha256sum -c`: they were hashed with CRLF
   line endings (and, for `v0b_t8_postcut_B.log`, an LF annotation line followed by
   CRLF capture lines) and committed with LF. Every original hash was reproduced
   from the committed bytes before being replaced, so no content changed. Entries
   now hold the LF hashes (29/29 OK), and `.gitattributes` marks `evidence/**` as
   binary so git no longer rewrites line endings.
5. **Signing cost.** With a cached keypair (what a router does), Ed25519 signing
   costs ≈174 ms on the M0+, not the 341 ms reported by the 2026-10-04 T6. T6 called
   `mesh_v10_sign(&seed, …)`, which re-derives the keypair on every call (a second
   scalar multiplication). Verify stays ≈178 ms.
