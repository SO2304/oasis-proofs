# oasis-proofs — the public evidence corpus of OASIS

This repository holds **proofs, not code**: campaign reports, their `SHA256SUMS`, journal
verdicts, Kani logs, fuzzing logs, SBOMs, and the specifications they refer to. The code lives
in `SO2304/oasis`, a **private** repository since 11 October 2026 (proprietary; access under NDA
or commercial licence). This corpus stays public so that the evidence can be checked without the code. No key, seed, client
configuration, serial number or real network address is in this repository.

Licence of this corpus: **CC BY 4.0** (see `RELICENSING.md`).

## Re-run on 2026-10-13: the essentials, on one PC

`evidence/rerun/2026-10-13/README.md` takes each essential claim in turn. For each one it shows what
was re-run that day, what is formally proven and what was shown on silicon, and it says what none of
it covers. All of it is at commit `53a64d7` of the code repository:

- **Tests:** 738 pass and 0 fail, on Linux (WSL2 Ubuntu 26.04, Rust 1.99.0) and on Windows 11 (Rust
  1.95.0).
- **Cryptography against official vectors:**
  - ChaCha20-Poly1305 against RFC 8439 §2.8.2;
  - HMAC-SHA256 against RFC 4231;
  - ML-DSA-44 against 15 NIST ACVP vectors, on two independent implementations.

  Of 20 072 single-bit flips, none is accepted. `cargo audit` finds 0 vulnerabilities.
- **Pilot campaign:** 72 of 72 cases pass. The shipped binaries, built for Linux, run against an
  independent Modbus device.
- **Kani:** 189 of the 189 non-heavy harnesses are verified, 0 refuted
  (`evidence/kani/2026-10-13/sweep/`). 83 of them are on the safety path. The 7 heavy ones were not
  attempted.
- **Silicon:** the 14 RP2040 campaigns, 970 files in all, match their manifests byte for byte. They
  were not re-run, because the boards were not connected.

## How to read it

- `evidence/real/2026-10-10/twohost-campaign-3/REPORT.md` — reference run: two physical
  machines, cable and LAN, 98/98 checks, cross-machine replay refused, external witness.
- `evidence/real/2026-10-09/sma/REPORT.md` — a real SMA inverter as target (partial: no write
  landed, Modbus server off).
- `evidence/silicon/` — three RP2040 boards, power cuts, signed updates, Modbus RTU brownfield.
- `evidence/pilot/2026-10-09/` — shipped binaries against an independent test device, 72 cases.
- `evidence/kani/` — formal proof runs with their logs and negative controls.
- `evidence/supply-chain/` — SBOMs, `cargo audit`, `cargo deny`.
- `docs/DOSSIER_PREUVE_1_1_9_SPEC.md` — how these files map onto Regulation (EU) 2023/1230
  Annex III 1.1.9 and 1.2.1, and what is **not** proven.
- `docs/ANTERIORITE.md` — the dated anchors (tag, bundle hash) of the code repository.

Every directory carries a `SHA256SUMS`; `tools/check_claims.sh --full` in the code repository
verifies all of them against the committed blobs.

## Work in progress — software only, not proven on hardware

- **LoRa transport, virtual tests** — `evidence/bench/2026-10-13/lora_sim/README.md`. The OASIS
  stack runs over a simulated LoRa radio at the byte layer, with these results:
  - a signed envelope is sent and verified, and a forged one is refused;
  - the EU868 1 % duty cycle is enforced by the transport itself;
  - frequency hopping is measured against three jammer models, K=10 per scenario. Every simulation
    was run twice with byte-identical output.

  **40 of the 41 tests pass.** The failing one predates the duty-cycle enforcement; it is recorded,
  not hidden. Time on air per message: `evidence/bench/2026-10-09/lora_budget/`.
- **What is missing.** No radio has ever transmitted. The SX1262 driver is tested against a
  simulated SPI bus only, and the time-on-air formula is not verified at the source. Next step: two
  SX1262 radios on RP2040 boards.
