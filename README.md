# oasis-proofs

I'm Souhayb. I'm building OASIS on my own, in Belgium, and this repository holds the evidence
for it. The code is private for now (I can open it under NDA if you need to look), but the proofs
are here so anyone can check them without having to take my word for anything.

## What OASIS is for

Most PLCs still speak Modbus, and Modbus has no authentication at all. Anything that can reach a
PLC on the network can write to it. Secure versions of these protocols have existed for about
twenty years, but hardly anyone uses them, mostly because you have to replace or reprogram the PLC.

OASIS goes another way. It's a small gateway that sits in front of the PLC, and the HMI and the
PLC stay exactly as they are. Every write is signed on the operator side by an identity that was
enrolled beforehand, and the gateway checks nine things before passing it on: is the signature
valid, is this identity allowed to write, has its key been revoked, is the order still fresh, is
the value inside the range set for that register, and so on. If one check fails, nothing reaches
the PLC. Every decision, accepted or refused, goes into a hash-chained log that someone else can
verify on their own.

## Why now

From 20 January 2027, the EU Machinery Regulation (2023/1230, Annex III, point 1.1.9) requires new
machines to be protected against corruption and to collect evidence of interventions, legitimate
or not. There is no harmonised standard for it yet (EN 50742 is still a draft), so machine
builders have to prove it their own way. OASIS is meant to give them that evidence for the
command path.

It is not a safety function and it never sits in the emergency-stop chain.

## Where to start

If you read only one file, make it `evidence/rerun/2026-10-13/README.md`. On 13 October 2026 I
re-ran everything on one PC (tests, the pilot campaign against a test PLC, the formal proofs), and
it says what each piece shows and what it doesn't.

After that, depending on what you care about:

- `evidence/real/2026-10-10/twohost-campaign-3/`: two real machines, over a cable and then a LAN.
- `evidence/silicon/2026-10-07/modbus/`: three RP2040 boards, one of them playing an old Modbus
  device. Only the authorised writes ever reached it.
- `docs/DOSSIER_PREUVE_1_1_9_SPEC.md`: how all this maps onto Annex III 1.1.9 (in French, sorry).

## What isn't done yet

I haven't tested it on a commercial PLC. The "PLC" in these campaigns is a simulator built on
rmodbus. I did point it at a real SMA inverter once, but its Modbus server was switched off, so no
write ever landed. Nothing has run for longer than a few minutes, there has been no external
security audit, and the LoRa radio side only exists in simulation.

If you build machines or look after PLCs and would like to try it on one machine, I'd really like
to hear from you. The easiest way is to open an issue here, or you can find me on GitHub as
[SO2304](https://github.com/SO2304).

## About this repository

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
