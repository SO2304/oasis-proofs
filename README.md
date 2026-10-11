# oasis-proofs — the public evidence corpus of OASIS

This repository holds **proofs, not code**: campaign reports, their `SHA256SUMS`, journal
verdicts, Kani logs, fuzzing logs, SBOMs, and the specifications they refer to. The code lives
in `SO2304/oasis`, a **private** repository since 11 October 2026 (proprietary; access under NDA
or commercial licence). This corpus stays public so that the evidence can be checked without the code. No key, seed, client
configuration, serial number or real network address is in this repository.

Licence of this corpus: **CC BY 4.0** (see `RELICENSING.md`).

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
