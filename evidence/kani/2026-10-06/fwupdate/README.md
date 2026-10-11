# Kani — Phase 1.3 harnesses (firmware install rule and floor)

Harnesses added with `oasis-rt/src/firmware.rs` (spec `docs/specs/FIRMWARE_UPDATE_SPEC.md`).
Run in WSL (Ubuntu, 3.3 GB RAM, `cargo-kani 0.67.0`) on a fresh checkout of the committed
tree with `run_fw_harnesses.sh <commit>`.

| Run | Tree | Result | Exit | Log |
|---|---|---|---|---|
| 1 | `200d96b` | **3 verified, 0 failures** (5.2 s, 0.1 s, 0.65 s) | 0 | `kani_fw_run1.log` |
| negative control | `200d96b` + 2 mutations (not committed) | **0 verified, 2 failures**, as intended | 1 | `kani_fw_negative_control.log` |

Negative control (`run_fw_negative_control.sh`):
- **Floor check disabled** in `install_decision`: `proof_fw_install_requires_all_conditions`
  fails with `assertion failed: i.manifest_version as u64 >= i.floor`.
- **`raised_floor` returns the running version:** `proof_fw_floor_never_lowers` fails with
  `assertion failed: f >= floor && f >= v as u64`.

A first launch of run 1 did not execute: Git Bash rewrote the `/mnt/c/...` path given to
`wsl.exe`. Its one-line error log was overwritten by the real run.

Proven properties (run 1):

| Harness | Property |
|---|---|
| `proof_fw_install_requires_all_conditions` | for all inputs: an accepted install has an authorized manifest, the right hardware, `0 < image_len ≤ 512 KiB`, a matching hash, an image version equal to the manifest's, `version ≥ floor` and `version > running` |
| `proof_fw_floor_never_lowers` | `raised_floor(floor, v) ≥ floor` and `≥ v` |
| `proof_fw_parsers_total` | `parse_manifest` and `image_version` never panic and accept only their exact lengths (manifest 48 B; header 0xC0 + 8 B) |

Limits:
- Signature verification and the SHA-256 are not modelled: the rule takes their results as
  inputs.
- The embassy-boot swap and revert are not proven here. They were tested on silicon
  (`evidence/silicon/2026-10-06/fwupdate/`).
- The floor's storage is `tx_lease::DualSlotStore`, covered by the existing lease harnesses.
