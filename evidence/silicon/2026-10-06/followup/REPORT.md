# v0B silicon follow-up — strict mode, byte-exact replay, sender counter lease

Prompt: `prompts/MESH_V0B_SILICON_FOLLOWUP.md`. Three RP2040 clone boards
(A→B→C over UART0, 115 200 baud). Firmware `uart_mesh` built from the **clean,
committed and pushed** tree **`3a67e6e`**; that stamp is on all 550 log lines in
this folder and is the only one present. Logs are LF (0 CR bytes). Hashes in
`SHA256SUMS`, re-verified in a fresh clone after the commit.

Start of session: `!` (test-harness factory reset of the receiver window and the
sender lease, on all three boards) because B still remembered `a_last_seen=165`
from the previous session — `00_reset_{A,B,C}.log`. Before every test `K` was
sent to A, B and C and each answered `MODE|strict_v0b=true`.

## Results

| # | Test | Expected | Obtained | Logs |
|---|---|---|---|---|
| 1 | Bit-flip sweep, strict mode, 3 × 50, numbered | 150 traced, 0 accepted; magic flips → `legacy envelope rejected…` or `bad mesh magic` | **150 sent / 150 traced at B / 0 accepted / 0 CRC failures / 0 correlation gaps**. Magic flips: 9/9 `legacy envelope rejected by strict v0B router` | `10_sweep_run{1,2,3}_{A,B}.log`, `11_sweep_correlation.txt` |
| 2 | Downgrade: strict B receives v0A, then `k` on B | refused, then accepted | strict: `DROP\|legacy envelope rejected by strict v0B router`; after `k`: `ARRIVED…sig=verified` + `RELAYED` (negative control); `K` restored | `20_…`, `21_…`, `22_…`, `23_…` |
| 3 | Byte-exact replay across a real power-cut of B | `replay detected` or `stale counter` | A sent counter 153 and stored the bytes; B accepted, persisted `a_last_seen=153`. **B unplugged.** After reboot B read `a_last_seen=153` back from flash; A (not reset: `tx=153`) re-sent the **same 111 bytes**; B, first frame since boot (`RXF n=1, ctr=153`): **`DROP\|stale counter`** | `30_…`–`33_…` |
| 4 | Sender lease across a real power-cut of A | rebooted A accepted by B | A sent counters 154–163, B accepted 10/10 (`a_last_seen=163`). **A unplugged.** A came back with **`tx=1279`** (the ceiling read from flash, not 0); its next message was **counter 1280** and B **accepted** it (`a_last_seen` 163 → 1280) | `40_…`–`43_…` |

### Per-field outcome of the 150 bit-flips (`11_sweep_correlation.txt`)

| flipped field | packets | decision at B |
|---|---:|---|
| magic | 9 | `legacy envelope rejected by strict v0B router` |
| network_id | 9 | `foreign network` |
| origin_fp | 13 | `unknown sender` |
| counter | 8 | `bad mesh signature` |
| ttl | 3 | `ttl/hops out of range` |
| hops | 2 | `ttl/hops out of range` |
| payload_len | 2 | `length mismatch` |
| signature | 83 | `bad mesh signature` |
| payload | 21 | `bad mesh signature` |

Every packet A logged (`SWEEP_TX seq=…, counter=…, field=…`) was matched to the
frame B logged (`RXF ctr=…, seq=…`) and its decision; one bit is flipped per packet,
so the counter or the sequence number always survives to make the match.

### What test 3 and 4 add over the 2026-10-06 run

- Test 3 is the **byte-for-byte** replay the earlier T8 did not run (that run sent a
  newly signed envelope with an old counter).
- Test 4 closes the liveness gap that run found: a rebooted origin used to restart at
  counter 1 and be refused; it now resumes above its persisted ceiling.
- B's own lease also resumed at its ceiling after its power-cut (`tx=1279` in
  `32_replay_postcut_B_status.log`).

## Sender lease — measurements and limits

- **Flash wear (PC, `oasis-rt` test `lease_one_durable_write_per_block`):** 40
  durable writes for 10 000 messages = 1 per 250, converging to 1/256. **On silicon**
  each board made exactly 1 lease write per boot (`lease_writes=1`) for the ≤ 163
  counters used — too few messages to measure the steady-state rate on the chip.
- **Torn writes:** two alternating checksummed slots (sectors `0x1FD000`/`0x1FE000`).
  PC tests cover tears at 4 points and 10 000 random reboots with ~2 % torn writes:
  no counter reused. A real power cut *during* a flash write was **not** produced on
  silicon.
- **Counters skipped per reboot:** the library reserves blocks of 256; the firmware
  reserves `tx + 1024` (+255) before each USB command buffer, so a reboot skips up to
  ~1 279 counters (A jumped 163 → 1280). Harmless — receivers need strict progress,
  not contiguity — and the u64 space makes exhaustion irrelevant.
- **A wiped or re-provisioned device restarts at 0** and will be refused by relays
  that remember it. `!` exists only for this test harness; re-provisioning in
  production must carry the counter forward or have relays forget the origin.
- **Endurance not measured.** At the datasheet's typical ~100 k erase cycles per
  sector and two alternating sectors, the estimate is ~5 × 10⁷ counters before wear
  out — an estimate, not a measurement.
- The **receiver** window is still flushed on demand (`P`) on the chip; the
  write-coalescing policy for the receiver is specified, not implemented.

## Not tested

Still a wire, not a radio (no LoRa / over-the-air). No secure element: the Ed25519
seed and both persistence areas are readable and writable over SWD by anyone with
the board in hand.
