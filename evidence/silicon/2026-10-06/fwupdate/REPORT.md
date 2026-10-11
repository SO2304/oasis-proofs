# Phase 1.3 on silicon — signed A/B firmware update

Spec: `docs/specs/FIRMWARE_UPDATE_SPEC.md`. Three RP2040 clone boards (A, B, C), wired
UART A→B→C (one-way). Logs are LF-only, straight from USB-CDC
(`OASIS|board|UART|event|value|mesh|stamp`). Lines starting with `#` and the port
transitions come from the PC harness (`harness/`). Signed manifests are in
`artifacts/` (hex), with the SHA-256 of every image in `artifacts/IMAGES.sha256`. The
images themselves are not committed; they are rebuilt from the stamped commit.

- **Bootloader** `oasis-bootloader` (embassy-boot 0.7.0 + embassy-boot-rp 0.10.0):
  5 892 B, built at `067855c`, the same binary on all three boards.
- **Application** `uart_mesh --features bootloaded`, stamp `200d96b`, for runs 20–44.
  C: v1 305 888 B, v2 305 904 B, v3 305 896 B, v3hang 303 192 B. A/B: v1 287 256 B,
  v3 287 264 B (no actuator code).
- Runs 00–13 are the bring-up (§1). Their logs carry the stamp of whichever image was
  running when they were read, as listed below.

## 1. Bring-up: seven failed first boots, then a USB defect

| Attempt | Stamp | Result | Logs |
|---|---|---|---|
| 1 | `23f97b2` | No USB, no BOOTSEL volume, nothing observable | `01_*` |
| 2 | `3bf817b` (bootloader on ROSC, guard in the app) | Same | (none) |
| 3 | `4b9cdbf` (flash breadcrumbs) | `B1 B2 B9` ×17, never `A1`: the bootloader jumps, the app never runs; watchdog reset every ~8 s | `02_*` (read with the `4b9cdbf` standalone image) |
| 4 | `8eec186` (clean NVIC hand-over, guard in the bootloader) | 3 failed boots, then the bootloader enters BOOTSEL by itself (`BF`) | `03_*` |
| 5 | `a42545e` (ROSC at nominal 6.5 MHz) | Identical to 4: clock speed not the cause | `04_*` |
| 6 | `268afcc` (SCRATCH markers in `pre_init`) | SCRATCH1/3 stay 0: the app's Reset handler never runs | `05_*` |
| 7 | `fc447d1` (vector table recorded at the jump) | `D2` = `0xFFFFFFFF` at 0x10008000, 0x10008004 and 0x10008100: **the application region is erased** | `06_*` |

**Root cause:** my merged UF2 (`harness/mkuf2.py`) left a partly filled 4 KiB sector
after the 8 KiB bootloader. RP2040 erratum **E14** (datasheet §2.8.4.2): such a UF2 *"may
not be written correctly"*, and the bootrom dropped the application pages. Once every
piece was padded to whole sectors, C booted v1 at the first try (`07_*`, images
`fc447d1`), with its identity, owner o2, 3 peers and revocation epoch 2 intact. My
clock, NVIC and `pre_init` hypotheses (attempts 2–6) were wrong. The changes they
produced stay as robustness and diagnostics: bootloader-side boot guard with BOOTSEL
fallback, clean NVIC hand-over, breadcrumbs.

`07_*` shows a `prev_boot_stage=17` field. It was misleading (overwritten by the boot's
own early markers) and was removed in `6a12139`.

**T1, first attempt** (bootloader without the fix; v1 `fc447d1`; v2 built at
`6a12139`): `10_*` install accepted; then the port never came back (`11_*`). After a
manual BOOTSEL, the breadcrumbs (`12_*`) and floor slots (`13_*`) show that the swap
completed (`B3`), v2 ran A1–A6 and the floor reached 2. USB was the defect: after a
soft reset, the D+ pull-up of the enumerated v1 stayed on, unclocked, during the whole
swap. **Fix `067855c`:** the bootloader holds USBCTRL in reset from its first
instruction.

**Design change `200d96b`** (found by reading the init path, not by a failure): the
image used to confirm itself right after loading its keys and then stop the watchdog. A
hang later in the init (router, v0B window, lease, revocation list) would have been
caught neither by the watchdog nor by the revert. Confirmation and watchdog stop now
happen at the main-loop entry. All test images were rebuilt at `200d96b`.

## 2. Tests on C (stamp `200d96b`)

Before the tests: bootloader + v1, `version=1, floor=2, state Boot`. The floor of 2 was
left by the first T1 attempt: the UF2 does not cover 0x1F2000.

| # | What | Result | Logs |
|---|---|---|---|
| T1 | v2, manifest o2 | **accepted** (check 957 ms) → port gone 17.708 s → `version=2, ConfirmedAfterSwap, state Boot`, same fingerprint | `20_*`, `21_*` |
| T2 | v3 with byte 150 000 flipped, valid o2 manifest | **`HashMismatch`** (940 ms), no reset | `22_*` |
| T3 | v1, valid o2 manifest | **`Rollback`** (939 ms): v1 < floor 2. The spec expected `NotNewer`; the floor rule is checked first and also forbids it | `23_*` |
| T4 | genuine v3, manifest signed by o3, then by o1 (previous owner) | **`NotAuthorized`** ×2, in 200.6 ms, before hashing. The spec said `BadSignature`; the firmware's reject code does not name the cause. 200.6 ms is close to Phase 1.2's forged-signature refusals (203–213 ms, which included ~4 ms of stack measurement) | `24_*`, `25_*` |
| T5 | v3hang (self-test never returns), manifest o2 | accepted → v3hang enumerates 17.714 s after the reset → **watchdog reset 7.528 s later** → revert (19.362 s) → `version=2, boot=Reverted, state Revert, floor=2` (unchanged), `guard_failed_before=1` | `26_*`, `27_*`, `28_*` |
| T6 | **power cut during the DFU upload** (paced upload, operator unplugged USB) | cut 10.2 s in; DFU held 6 whole sectors of v3 (24 576 B); sectors 6–15 (first 64 B of each, sampled) matched the image T5 swapped out. C rebooted on v2 (`B4` = state Revert, v2 code word). The v3 manifest alone: **`HashMismatch`**, though the image's version header was already in place | `30_*`–`32_*` |
| T7 | full v3 uploaded, manifest o2, **power cut during the swap** | **accepted** (955 ms; positive control for T4: same v3 bytes as T4). Breadcrumbs: the reset-for-swap record **ends at `B1`** (power lost inside `prepare_boot`), next a power-on record with `B3` (swap resumed), v3 code word, `A1–A6`. `version=3, ConfirmedAfterSwap, floor=3`, state `0xD0` (BOOT_MAGIC) | `33_*`–`35_*` |

How the breadcrumbs are read (`28_*`, `32_*`, `35_*`):
- **Bootloader record per boot:** `C1` + SCRATCH3 (the previous boot's last stage) +
  SCRATCH2 low byte (guard count), then `C2` + SCRATCH1, `B1`, the state crumb
  (`B2` Boot, `B3` Swap, `B4` Revert), `D1` NVIC masks, `D2` + three words read at
  0x10008000/04/100, `B9`.
- **Application crumbs:** `A1`–`A6`, where `A5` = confirmed and `A6` = main loop.
- **Code words at 0x10008100:** v1 `0xffd4f00b`, v2 `0xffdaf00b`, v3 `0xffd8f00b`,
  v3hang `0xff9af00b` (checked against the image files).

**T5:** v3hang's record ends at `A4` (no `A5`). The next boot reads SCRATCH3 = 3 and
guard count 1, and the code word after the revert is v2's again.

**T6 and T7 power-on:** SCRATCH3 = 0 marks a power-on reset. A soft or watchdog reset
keeps the previous stage, 100 = main loop.

**Why T7's cut was during the swap:** if the swap had completed before the cut, the
next boot would have found `Swap` already swapped and **reverted** to v2. It booted v3.
How far the swap had progressed is not recorded, because `mark_booted` rewrites the
state sector.

**T6 had two power cuts.** The operator unplugged twice (11.3 s, then 18.2 s off). Both
records show a power-on (SCRATCH3 = 0) and state Revert. Only the first cut interrupted
writes; after it, the harness wrote into a dead handle.

## 3. A and B, and the mesh

| # | What | Result | Logs |
|---|---|---|---|
| 40–41 | First flash of bootloader + v1 on A and B (UF2, identity sector untouched) | `version=1, floor=1`, fingerprints A `822460d2…`, B `f6bd3444…` (same as Phase 1.2) | `40_*`, `41_*` |
| 42–43 | v1 → v3 through the signed path (manifest o2) | accepted (A 692 ms, B 688 ms), swap 17.904 / 16.821 s, `version=3, ConfirmedAfterSwap, floor=3` | `42_*`, `43_*` |
| 44 | A originates a v0B payload (`@P`), all three on v3 | **B `ARRIVED sig=verified` → `RELAYED`, C `ARRIVED sig=verified` (hops 1)**; A's counter 5117 did not restart from 0 (its lease was restored) | `44_*` |

The enrollment registry, owner, revocation epoch and counter lease all survived the
bootloader install and the update. A's and B's install check is ~260 ms faster than
C's for a 6 % smaller image. Not investigated; every check time here is a single run
(one per test), not a banded figure.

## 4. Kani

`evidence/kani/2026-10-06/fwupdate/`: 3/3 harnesses verified on a fresh checkout of
`200d96b` (exit 0). A negative control (floor check removed, `raised_floor` mutated)
makes both rule harnesses fail.

## 5. Errors in this phase

- **The seven failed boots** were mine (unpadded UF2, §1). The commit messages of
  `8eec186` and `fc447d1` cite placeholder stamps ("9b1b1b0-era", "6c1e3a2-era"). The
  real stamps are `4b9cdbf` and `268afcc`; errata are in `a42545e` and `6a12139`.
- **`11_*` first said "port gone -> back = 186 s".** That was the wait loop's timeout:
  the port never came back. Corrected before commit; the file says so.
- **The first Kani launch did not run:** Git Bash rewrote the `/mnt/c/...` path given to
  `wsl.exe`. That one-line log was not a Kani result and was overwritten by the real run.
- **`@X` lines sent to A and B while they still ran `4713703`,** which has no `@X`. The
  `@` line is diverted whole and unknown lines are ignored, so nothing ran (no output,
  no lease write).

## 6. Limits

- **No secure boot.** The RP2040 cannot verify the image at boot (the RP2350 can). The
  gate is the running application. BOOTSEL, SWD, or this test firmware's `b` command
  can write any image. The floor survives a BOOTSEL reflash but does not stop one.
- **What "does not start" covers:** any reset or hang before the main loop is
  reverted. After confirmation (main-loop entry), a functional bug stays. The self-test
  verifies one known hybrid vector, not the UART or the mesh.
- **The boot guard** (3 failed boots → BOOTSEL) lives in watchdog scratch registers,
  which a power-on clears.
- **One cut per case:** T6 cut at 24 KiB only, T7 at an unknown point of the swap. Not
  tested on silicon:
  - a cut during the revert;
  - a cut between the floor raise and `mark_booted`;
  - a cut during the `mark_updated` state write.
- **USB only;** no distribution over the mesh (spec §5). The bootloader itself is
  neither updatable nor signed.
- **The swap copies the whole 512 KiB partition** (≈ 17–18 s reset to USB) whatever the
  image size.
- **`embassy-boot` has no known external audit.** We rely on its design, its tests and
  the two cuts above. The Kani proofs cover our install rule and floor only.
