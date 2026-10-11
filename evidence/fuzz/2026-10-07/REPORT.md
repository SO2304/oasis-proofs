# Phase 2.3 — fuzzing the parsers (cargo-fuzz)

Prompt: `prompts/OASIS_VS_VERIDIFY.md`, phase 2, point 3 — fuzz the parsers (v0B, ORV1,
OAC1, enrollment attestation, update header, Modbus frames) and report the hours and the
cases found.

**Setup.** `cargo-fuzz` 0.13.2 (libFuzzer) on **Windows**, `nightly-2025-11-21`, with the
MSVC AddressSanitizer runtime on PATH (`clang_rt.asan_dynamic-x86_64.dll` from the VS
Build Tools; without it the targets exit `STATUS_DLL_NOT_FOUND`). WSL was unusable, so
this did not need it. 4 cores, 4 targets in parallel per batch, `-max_total_time=3600`
each. Targets: `oasis-rt/fuzz/fuzz_targets/`, harness `harness/fuzz_campaign.sh` and
`harness/fuzz_batch2.sh`.

## 1. Hours and volume

8 targets × 1 h = **8 target-hours**, ~2 h wall clock in two batches of four.

| Target | Executions | Coverage (edges) | Features | Corpus | exec/s | Result |
|---|---:|---:|---:|---:|---:|---|
| `mesh_v0b` | 2 465 784 | 1 009 | 1 585 | 75 | 684 | DONE, 0 crashes |
| `authority` | 81 910 459 | 617 | 981 | 162 | 22 746 | DONE, 0 crashes |
| `modbus` | 207 277 840 | 212 | 245 | 35 | 57 561 | DONE, 0 crashes |
| `revocation` | 232 779 208 | 175 | 303 | 57 | 64 642 | DONE, 0 crashes |
| `actuation` | 300 288 239 | 98 | 98 | 5 | 83 390 | DONE, 0 crashes |
| `enrollment` | 277 255 437 | 180 | 180 | 46 | 76 994 | DONE, 0 crashes |
| `firmware` | 305 454 703 | 62 | 62 | 5 | 84 824 | DONE, 0 crashes |
| `mavlink` | 91 933 393 | 244 | 261 | 45 | 25 529 | DONE, 0 crashes |

**Total ≈ 1.50 × 10⁹ executions.** `mesh_v0b` is three orders of magnitude slower
because two of its three modes sign and verify real Ed25519 envelopes per input.

## 2. Cases found: one

**OAC1 reserved bytes accepted any value** — found by the `actuation` target on its
**first run, within 60 s**, through the round-trip assertion (a parsed command must
re-encode to the input bytes).

- `OAC1_LEN` is 54 but the fields end at byte 50. `parse_oac1` ignored bytes 50..54
  while `encode_oac1` writes zeros, so one command had 2³² encodings (non-canonical).
- **Not exploitable**: those bytes are inside the v0B-signed payload, and replays are
  refused by `cmd_seq` and the v0B counter window. It is a canonicalisation defect.
- Fixed in `f26195b`: the parser now requires zeros there, with the regression test
  `act_oac1_reserved_bytes_must_be_zero` (it fails on the old parser). Every OAC1
  payload recorded on silicon already had zeros, so no message on the wire changed.
- Reproducer kept: `oac1_noncanonical_reproducer.bin` (54 bytes). On the **fixed**
  parser it is simply refused; it panics only on the pre-fix code.

Nothing else was found in 1.50 × 10⁹ executions. The remaining file under
`fuzz/artifacts/actuation/` is that same reproducer.

## 3. A fix to the fuzzing itself

On Windows a Rust panic aborts through `__fastfail`, which libFuzzer cannot intercept,
so **no crash file is written and the failing input is lost**. `fuzz_targets/common.rs`
installs a panic hook that saves the current input to `fuzz/artifacts/<target>/` before
aborting. Verified by running the `actuation` target against the pre-fix parser: it found
the defect in 60 s and saved the input.

## 4. Limits

- **1 h per target** is a smoke-level budget, not an assurance campaign. Coverage had
  plateaued on all 8 by the end, but plateaued coverage is not proof of absence.
- **No structure-aware fuzzing** (no `arbitrary`-derived grammars): inputs are raw bytes,
  so deep paths behind a signature check are reached only through the corpus seeds the
  targets build themselves. `mesh_v0b` mitigates this by signing real envelopes in two of
  its three modes.
- **Coverage is edge coverage of the fuzzed crate**, not of the firmware.
- **No sanitizer beyond ASan**; the code is `#![forbid(unsafe_code)]`-free but contains
  little unsafe, so ASan findings were never likely.
- Corpora are **not committed** (`fuzz/.gitignore`); they live on the build machine, so a
  re-run starts cold unless they are preserved.
- `mesh_v0b` at 684 exec/s explored far less input space than the others; a longer run
  for that target specifically would be the first thing to extend.
