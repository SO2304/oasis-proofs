# Phase 1.2 on silicon — enrollment and ownership transfer

Spec: `docs/specs/ENROLLMENT_OWNERSHIP_SPEC.md`. Three RP2040 clone boards (A, B,
C), wired UART A→B→C (one-way), strict v0B. Logs are LF-only, straight from USB-CDC
(`OASIS|board|UART|event|value|mesh|stamp`). Tool lines (`# …`, `POP_OK`, `exit=`)
come from the PC harness (`harness/`). Every payload sent is in `payloads/` (hex).

Firmware `uart_mesh`: identity generated on the board (`src/enroll.rs`), no compiled
seeds or registry; authority gate as in Phase 1.1 (`src/pq.rs`). Two stamps:

- `5c4bd96`, runs 00–09 and the enrollment logs 50–52 (29 logs). Run 09 exposed the
  missing pacing between fragments (§3);
- `4713703`, runs 10–44 (50 logs): the same firmware plus a 100 ms gap after each
  fragment. Images archived: `firmware_uart_enroll_{A,B,C}.uf2` (4713703 only; the
  5c4bd96 images differ only by that gap). Text 280 212 B on A/B, 298 836 B on C
  (actuator code). RAM statics are unchanged at 98 340 B.

Audit: 101 logs, 1 604 board lines, every one stamped. The only `DROP`/CRC lines are
the expected ones (04, 06, the failed 09). 21 board logs are empty: expected
silences (nothing forwarded).

## 1. Identity generated on the board

| # | What | Result | Logs |
|---|---|---|---|
| 00–01 | State before, then factory reset `!` on A, B, C | wiped | `00_*`, `01_*` |
| 02 | First boot after the wipe | 3 new, distinct fingerprints (A `3841bfd4…`, B `e5c7265f…`, C `cf9e7036…`), `mixed=false`, owner #1 (`0beef5a9…`), 0 peers | `02_*` |
| 03 | `@N`: 100 000 raw ROSC bits (100 cycles apart), 3 runs per board | ones **43.4–47.0 %** (biased toward 0), longest run 19–29 (< 41), SP 800-90B MCV estimate **0.810–0.905 bit/sample**; RCT and APT pass on 9/9 | `03_*` |

The MCV estimate measures bias only, not correlation. The RP2040 datasheet
(§2.17.5, p. 224) still says the ROSC bit *"does not meet the requirements of
randomness for security systems because it can be compromised"*: these figures
don't contradict that and don't certify anything. The design assumes 0.5
bit/sample and samples 8× what that requires.

## 2. Unenrolled nodes refused, enrollment, propagation, permissions

| # | What | Result | Logs |
|---|---|---|---|
| 04 | A (not enrolled) sends a v0B payload | **B: `DROP unknown sender`**, C nothing | `04_*` |
| 50 | Tool enrollment of A, B, C (`harness/enroll_board.sh`): `@E` → the board mixes the tool's nonce into its key once, persists it and reboots (`REKEYED old_fp→new_fp`) → `@E` → `IDENTITY` + `POP` → tool `verify-pop` → o1 signs the attestation | 3/3 `POP_OK`; final fingerprints A `822460d2…`, B `f6bd3444…`, C `a7089677…`, `mixed=true`. A: relay + `ACTUATE`; B: relay; C: actuator | `50_*`, `payloads/att_*` |
| 51 | Proof-of-possession controls (tool side, on A's recorded proof) | recorded challenge `POP_OK`; one challenge nibble changed `POP_FAIL`; B's key with A's proof `POP_FAIL` | `51_*` |
| 06 | A's attestation loaded on B over USB (`@L`, same gate as the mesh) | B `Enroll(Enrolled)` (387.8 ms) and re-originates 14 fragments; **C drops all 14: `unknown sender`** (B not enrolled at C) | `06_*` |
| 07 | A's and B's attestations loaded on C | `Enrolled` ×2, 2 peers | `07a_*`, `07b_*` |
| 08 | A sends a v0B payload again | B verifies and relays, C verifies at hop 1 | `08_*` |
| 09 | C's attestation over the mesh from A (`@L`) | **FAILED**: B got fragments 0, 2, 5, 8, 11 of 14, 3 CRC failures, 1 garbled header → see §3 | `09_*_FAILED_fifo_overrun_*` |
| 10 | Reflash with paced fragments (4713703); identities and registries persist across the reflash; `Y` timing | v0B sign 178.1 ms, verify 184.3–184.8 ms | `10_*` |
| 11 | C's attestation over the mesh, `@F` from A (A already held it from run 09) | **B 14/14 → `Enrolled`, re-originates → C 14/14 → `Enrolled`** (its own), 0 CRC | `11_*` |
| 13 | Order (OAC1) from B, enrolled **without** `ACTUATE` | C: **`Reject(NotAuthorized)`** | `12_*`, `13_*` |
| 14 | Order from A with a 30 s validity (harness error) | C: `Reject(Expired)`: the gate caps validity at `MAX_VALIDITY_MS` = 10 s (it was authorized, so it reached that check) | `14_*attempt1*` |
| 16 | Order from A, 9 s validity | C: **`Act`**, pin 25 = 1 | `15_*`, `16_*` |

## 3. Run 09: no flow control, and an error carried over from Phase 1.1

The wire has no flow control, and a receiver reads its 32-byte UART FIFO only between
frames. On this firmware a v0B **sign** takes **178 ms** (`10_*`, `Y`). The sender's
period was therefore ~204 ms (sign + 26 ms on the wire), against a receiver per-frame
cost of ~185 ms of verification plus logging. Phase 1.1 passed with that ~10 ms margin.
Phase 1.2's extra per-frame work removed it, and B's FIFO overflowed (run 09).

I had reasoned with **341 ms** per sign, a figure from the T6 suite (a different
firmware), in Phase 1.1's report and messages. That was wrong for `uart_mesh`; see the
erratum in `../pq/REPORT.md`. Fix: `send_fragments` waits 100 ms (USB polled) after
each fragment (commit `4713703`). From run 10 on, every fragmented transfer arrived
complete with 0 CRC failures (14/14 or 21/21 per hop).

## 4. Ownership transfer o1 → o2

| # | What (all loaded on A with `@L`, then store-and-forward) | A | B | C | Logs |
|---|---|---|---|---|---|
| 20 | Revocation signed by o1, epoch 1 | `Applied` | `Applied` | `Applied` | `20_*` |
| 21 | **Offer**, signed by o1, new owner o2 (3 849 B, 21 fragments) | `OfferPending` | `OfferPending` | `OfferPending` | `21_*` |
| 22 | Acceptance signed by **o3** (attacker) | **`Rejected(BadSignature)`** in 203 ms (checked against the offered o2 keys), not forwarded | — | — | `22_*` |
| 23 | **Acceptance** signed by o2 | **`Transferred`** | **`Transferred`** | **`Transferred`** | `23_*` |
| — | New owner key on every board: `5b8649c0cfcdbe78…`, independently derived as o2's Ed25519 key with Python `cryptography` | | | | `23_*` |
| 24 | Attestation signed by **o1** (old owner) | **`Rejected(BadSignature)`** | — | — | `24_*` |
| 25 | The same attestation signed by **o2** | `Enrolled` | `Enrolled` | `Updated` (seq 1→2) | `25_*` |
| 26 | The acceptance again (nothing pending) | **`NoPendingOffer`**, no verification | — | — | `26_*` |
| 27 | The old o1 offer replayed | **`Rejected(BadSignature)`** | — | — | `27_*` |
| 28 | New offer o2 → o3 while the persisted list is still signed by o1 | **`NeedsResign`** | — | — | `28_*` |
| 29 | o2 re-signs the list (epoch 2) | `Applied` | `Applied` | `Applied` | `29_*` |
| 30 | The same offer o2 → o3 | `OfferPending` | `OfferPending` | `OfferPending` | `30_*` |

(B is enrolled at A only from run 25 on, which is why A reports `Enrolled`.)

## 5. Real power cut of B (operator unplugged USB after `31_*`)

After the reboot (`40_*`: uptime 19.9 s, `boot_id` 2558→3837, frame counters reset),
B shows:
- the **same fingerprint** `f6bd34440030a136` (`mixed=true`);
- **owner o2** (`owner_seq=1`, previous owner kept);
- the **same 3 peers** with their permissions and sequences;
- **revocation epoch 2**, re-verified at boot against the **current** owner's keys
  (`rev_signer=Current`);
- the **pending offer gone** (RAM only, as specified).

| # | After the cut | Result | Logs |
|---|---|---|---|
| 42 | Attestation signed by o1, loaded **directly on B** | **`Rejected(BadSignature)`** | `42_*` |
| 43 | A sends a v0B payload | B verifies and relays, C verifies | `43_*` |
| 44 | The o2 → o3 offer sent again from B | B `OfferPending` (its pending offer was lost), C **`DuplicateOffer`** (kept it), not forwarded; 21/21, 0 CRC | `44_*` |

## 6. Figures

- **Authority gate:** every full verification took **381–400 ms** (the 3 849-byte
  offers are the slow end). Every forged signature was refused in **203–213 ms**,
  because ML-DSA-44 fails first. Peak stack was 49 244 B every time.
  `verify_us` includes ~4 ms of stack measurement (Phase 1.1 §2).
- **Per hop:** a 14-fragment message costs ~14 × (178 + 26 + 100) ms to send plus
  ~380 ms to verify, about 4.6 s; a 21-fragment offer about 6.8 s.

## 7. Limits

- **The key is not protected by hardware.** The firmware never prints the seed, but
  flash is readable in BOOTSEL (picotool) or over SWD, and this test firmware reboots
  to BOOTSEL on `b`. Anyone with physical or USB access can read the key.
- **ROSC entropy.** Not a validated source (datasheet §2.17.5). Health tests catch a
  stuck or grossly biased source only. The tool nonce, mixed in once, protects against
  third parties, not against the tool itself if the ROSC has no entropy.
- **Ownership is per network**, not a per-device chain. The initial owner is compiled
  in. There's no hybrid k-of-n for the owner.
- **Partial enforcement.** Roles are logged only; `ACTUATE` is the only permission
  enforced.
- **Persisted state.** The registry and the owner record are integrity-checked (4-byte
  SHA-256 check), not signature-verified, at boot. A pending offer does not survive a
  reboot.
- **Wired UART, no flow control.** The 100 ms gap is a pacing workaround; a receive
  interrupt with a ring buffer would remove the dependency on timing. No radio.
- Not tested on silicon: a torn flash write of the owner record or the registry during
  a real power cut (unit-tested with simulated tears).
