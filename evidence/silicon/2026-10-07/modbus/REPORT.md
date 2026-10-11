# Phase 1.4 on silicon — Modbus RTU gateway in front of a brownfield device

Spec: `docs/specs/MODBUS_GATEWAY_SPEC.md`. Three RP2040 clone boards.

**Logs and artifacts:**
- Logs are LF-only, straight from USB-CDC: `OASIS|board|UART|…|mesh|stamp` for the
  OASIS nodes, `OASIS|A|MODBUS|…|device|stamp` for the device.
- Lines starting with `#` come from the PC harness (`harness/`).
- Orders and attestations sent are in `payloads/`. Signed update manifests and image
  hashes are in `artifacts/`.

| Board | Role | Firmware |
|---|---|---|
| **A** | existing Modbus RTU device: unit `0x11`, `rmodbus` 0.12.2, **no OASIS code**, counts every byte on its bus | `modbus_device` `a39d5fe`, 18 576 B, flashed over BOOTSEL (`03_*`) |
| **B** | order origin (PC → B over USB, then B → C over the mesh, one hop) | `uart_mesh` v4 `a39d5fe` (`02_*`), then v5 `bbee4cf` (`15_*`, adds `@H`), both through the signed update path |
| **C** | gateway: the only writer on A's bus | `uart_mesh` v4 `a39d5fe` (`01_*`), through the signed update path |

**Bus:** UART1, C.GP4→A.GP5 and A.GP4→C.GP5, 19 200 baud 8E1, TTL 3.3 V, no RS-485.
Over the whole run A counted **0 receive errors** and 0 overflows.

**Ground truth:** A's counters (`@D`, appended to every `*_A.log`). "Never reached the
device" means A's byte counter did not move.

## 1. Tests

**Setup (no test):**
- B got `ACTUATE` from an o2 hybrid attestation (sequence 3), loaded on C: `Enroll(Updated)`
  in 381.9 ms (`04_*`).
- G0 baseline: B peer with permissions 1 at sequence 3; gateway idle; A at 0 bytes (`05_*`).

| # | Order or injection | C | A (bytes / frames / writes) | Logs |
|---|---|---|---|---|
| G1 | valid order from B, FC06 `0x10` = 215 | `Act`; frame `1106001000d7cac1`; `Ack`, round trip 11.4 ms | **8 / 1 / 1**, register `0x10` = 215 | `10_*` |
| G2a | v0B envelope claiming B's fingerprint, signed with a fresh random key (PC `forge-v0b`), injected by B (`@J`) | `DROP bad mesh signature` → gate `Reject(NotVerified)` | unchanged | `12_*` |
| G2b | B signs a valid order and keeps it (`@H`). A copy with the value byte flipped (220→221) is sent under that never-seen counter (`@K130`), then the genuine envelope (`z`) | copy: `DROP bad mesh signature` → `NotVerified`; genuine: `Act`, `Ack` | 16 / 2 / 2, `0x10` = 220 | `16_*` |
| G3a | byte-exact replay of G1's envelope (`z`) | `DROP stale counter` (window bit already set, refused before the signature) | unchanged | `14_*` |
| G3b | executed `cmd_seq` 2 again, fresh deadline, new envelope | `Reject(StaleOrReplayed)` | unchanged | `17_*` |
| G7 | G2b's exact order bytes (deadline now past), new envelope | `Reject(Expired)` | unchanged | `18_*` |
| G4a | register `0x0020` (not in the map) | `Reject(OutOfLimits)`, `RegisterNotAllowed(32)` | unchanged | `19_*` |
| G4b | `0x10` = 900 (90 °C) | `Reject(OutOfLimits)`, `ValueOutOfRange(16, 900)` | unchanged | `20_*` |
| G4c | FC05 (coil) | `Malformed` (refused at parsing) | unchanged | `21_*` |
| G5a | raw RTU frame `1106001003848a0c` (FC06 `0x10` = 900, valid CRC) sent unframed on the B→C wire (`@R`) | nothing: C's receive bytes 1644→1652, frames 12→12 | unchanged | `22_*` |
| G5a′ | same frame, mesh-framed (`@J`) | `DROP bad mesh magic` | unchanged | `23_*` |
| G5b | same frame as the payload of a **validly signed** v0B envelope from B | `ARRIVED sig=verified`; not an `OMB1` order, so nothing goes to UART1 (relayed on the mesh UART only) | unchanged | `24_*` |
| G6 | valid order while C's sensor is reported lost (`U`) | `Reject(R14Unsafe)`, entropy 0.908 | unchanged | `25_*`–`27_*` |
| ctl1 | valid order after all the refusals | `Act`, `Ack` | 24 / 3 / 3, `0x10` = 230 | `28_*` |
| G8 | **control:** the G5 frame fed to A's parser directly over USB (`@Z`) | — | **executed** (`0x10` = 900). The device alone does not defend itself. Not bus traffic: `local_frames=1`, bus counters unchanged | `29_*` |
| G3c | after C's power-on reset (§2), G1's order and ctl1's order (both stamped `boot_id` 21232) resent in fresh envelopes | `Reject(Expired)` ×2. After the reboot `last_seq` was empty, so only `boot_id` stopped them | unchanged | `32_*`, `33_*` |
| ctl2 | valid order in the new boot (`boot_id` 22511) | `Act`, `Ack` | 33 / 5 / 4, `0x10` = 240 | `34_*` |
| G4d | B's `ACTUATE` withdrawn (o2 attestation, sequence 4, `Enroll(Updated)` in 383.5 ms), then a valid order from B | `Reject(NotAuthorized)` | unchanged | `35_*`, `36_*`, `38_*` |

**Final accounting** (`37_*`, computed over all logs):
- **C:** 4 `Act` decisions; 4 frames sent (32 bytes); 4 `Ack`. 12 gate refusals (all
  six reasons: NotVerified, StaleOrReplayed, Expired, OutOfLimits, R14Unsafe,
  NotAuthorized), 1 malformed order, plus the v0B drops.
- **A:** 33 bytes, 5 frames, 4 writes on its bus:
  - frames 1, 2, 3 and 5 are byte-for-byte the gateway's 4 frames, all `write_applied`;
  - frame 4 is one byte received during C's power-on (§2), with no write.
- **The only writes A ever received came from `Act` decisions.**

Figures are single runs, not banded: device round trip 11.29–11.39 ms (4 values);
attestation checks 381.9 and 383.5 ms.

## 2. Anomaly: C power-on reset, and one byte on A's bus

**What happened:**
- Between ctl1 (≈00:44Z) and G8, C rebooted: `boot_id` 21232 → 22511, all gateway
  counters reset (`30_*`).
- `now_ms=212642` at 00:50:09Z puts the boot at ≈00:46:37Z.
- C's bootloader breadcrumbs (`31_*`) record it as a **power-on reset**: SCRATCH3 = 0,
  where a software or watchdog reset keeps the last stage, 100. No firmware command
  can cause that.
- The cause is not recorded: an unplug, or a USB supply dropout. My session was
  interrupted at about that time, and I asked the operator. G3c uses this reboot.
- During it, A received **one byte** on its bus, counted as frame 4. Nobody was
  reading A's port, so its log line was lost. It caused no write (writes stayed at
  3, parse errors 0).

**Explanation, not verified:** on a power-on, C's GP4 is undriven or pulled down
until its UART starts, and A's input can read that edge as a start bit.

**Consequence:** a gateway power cycle can put a stray byte on the device bus. Here
it formed no valid request. RS-485 transceivers with fail-safe biasing are the usual
remedy on real buses.

## 3. Errors in this run (logs kept)

- **G2a, attempt 1 (`11_*`):** the harness opened C's port after B's instant `@J`
  injection, so C's `RXF`/`DROP` lines were lost. C's counters showed the frame
  arrived; A stayed at 8 bytes. `mb_send.sh` now waits 1.5 s before sending.
- **G2b, attempt 1 (`13_*`):** I flipped a payload byte of G1's envelope, whose
  counter C had already seen. C refused it as `stale counter` before any signature
  work, so the content check was not exercised. Commit `bbee4cf` added `@H` (sign
  without sending); G2b was redone with a never-seen counter (`16_*`).
- **`35_*_C_peers_EXTRACT.txt`:** fields cut before saving, so it is not a raw log.
  The raw final read is `38_*`.

## 4. Limits

- **Only if the gateway is the device's only path.** Whoever is wired to A's bus
  writes anything (G8). That is a deployment condition, not a proved property.
- **What the silicon run covers:** FC06 only. FC16 is tested on the PC against
  `rmodbus` (`mb_*` tests), not on silicon. No reads, by design.
- **Hardware and topology:** TTL, no RS-485, one device, 19 200 baud, one mesh hop
  (B → C). No Modbus TCP.
- **The register map is compiled into C, not signed.**
- **A timed-out write stays consumed.** The commander gets no end-to-end confirmation.
- **A is no longer an OASIS node.** It must be reflashed with the bootloader and
  `uart_mesh` (padded UF2) before later phases need it in the mesh. Its identity
  sector was not touched.
- **"The only UART1 write is in `mb_exchange`"** is checked by reading the code, not
  proven (Kani covers the pure rule: `evidence/kani/2026-10-07/modbus/`).
