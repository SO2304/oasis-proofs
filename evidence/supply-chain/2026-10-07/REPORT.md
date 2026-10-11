# Phase 2.4 — supply chain: audit, deny, SBOM (2026-10-07)

Tools:
- `cargo-deny` 0.19.8, with `deny.toml` at the repository root;
- `cargo-audit` 0.22.2, RustSec advisory database commit `ef6173c` (2026-10-03,
  1 290 advisories), cloned to a separate directory with `--db`, because
  `~/.cargo/advisory-db` holds cargo-deny's database in another layout;
- `cargo-cyclonedx` 0.5.9.

Six dependency graphs: the Cargo workspace (`oasis-rt`, `oasis-operator-key`,
`oasis-secure-element`, `oasis-trl-harness`) and the five firmware crates excluded from
it, each with its own lockfile.

## 1. Results

| Graph | Crates in lockfile | `cargo audit`: vulnerabilities | Informational advisories | `cargo deny check` |
| --- | ---: | ---: | --- | --- |
| workspace | 147 | **0** | RUSTSEC-2026-0173 | ok (exit 0) |
| `oasis-silicon-test` | 181 | **0** | 2026-0110, 2024-0436, 2026-0173 | ok |
| `oasis-bootloader` | 134 | **0** | 2026-0110, 2024-0436, 2026-0173 | ok |
| `oasis-lora-transport` | 103 | **0** | 2026-0173 | ok |
| `oasis-mcu-demo` | 157 | **0** | 2026-0110, 2024-0436, 2026-0173 | ok |
| `oasis-renode-m11` | 149 | **0** | 2026-0110 (`bare-metal` 0.2.5 and 1.0.0), 2026-0173 | ok |

The three informational advisories are documented exceptions in `deny.toml`. None
is a vulnerability.

| ID | Crate | Kind | How it gets in | Why kept |
| --- | --- | --- | --- | --- |
| RUSTSEC-2026-0173 | `proc-macro-error2` 2.0.1 | unmaintained | build-time proc-macro: `libcrux-ml-dsa` → `libcrux-intrinsics` → `core-models` → `hax-lib` → `hax-lib-macros` | runs on the build host only; goes when libcrux drops it |
| RUSTSEC-2026-0110 | `bare-metal` 0.2.5 (and 1.0.0 in `oasis-renode-m11`) | deprecated | runtime: `cortex-m` 0.7.9 (under `rp2040-hal`, `embassy-rp`, `stm32f4xx-hal`) | no replacement without leaving `cortex-m` 0.7, the base of every Cortex-M HAL used |
| RUSTSEC-2024-0436 | `paste` 1.0.15 | unmaintained | build-time proc-macro: PIO crates of `rp2040-hal` 0.10 and `embassy-rp` 0.10 | build host only |

Duplicate versions (warnings, not failures) are listed in `deny_*.log`: for
example `chacha20` 0.9/0.10, `crypto-common`, `getrandom` 0.2/0.4, and in firmware
`embedded-hal` 0.2/1.0 and `heapless` 0.8/0.9.

## 2. What was found and fixed

1. **No crate declared a licence.** The repository is MIT (`LICENSE`), but no
   `Cargo.toml` said so, so SBOMs and `cargo deny` saw our own crates as
   "unlicensed". Added `license = "MIT"` to the nine crates. This records the current
   licence; it does not choose one (`POSITIONING_GAPS.md` D4 is still open).
2. **Path dependencies had no version** (`oasis-rt = { path = … }`): 7 in the
   workspace and 6 in firmware crates, refused as wildcards. Each now pins the
   crate's version (`0.3.0` / `0.1.0`).
3. **`anyhow` 1.0.102 is unsound** (RUSTSEC-2026-0190, `Error::downcast_mut`,
   patched in 1.0.103):
   - it was only in the workspace lockfile, reached through `getrandom` 0.4 →
     `wasip3` → `wit-bindgen`, i.e. the `wasm32-wasip3` target only;
   - no `anyhow` artifact exists in any of the six `target/` directories (never
     compiled here);
   - `cargo deny` did not flag it, because it is outside the resolved graph for our
     targets; `cargo audit` scans every lockfile entry;
   - bumped to 1.0.104 (`cargo update -p anyhow`, nothing else changed).
4. **Three firmware lockfiles were stale.** `oasis-lora-transport`, `oasis-mcu-demo`
   and `oasis-renode-m11` did not list `oasis-rt`'s dependencies added since Phase
   1.1 (`libcrux-ml-dsa` and its tree, `crc`), so these crates had not been built
   since. `cargo deny` re-resolved them: additions only, plus 2 dependency lines per
   file now naming a version. All three build with the refreshed lockfiles
   (`cargo build --release`, exit 0).
5. **`stm32f4xx-hal` (`oasis-renode-m11`) is 0BSD.** OSI-approved and more
   permissive than MIT: added to the allowed licences.

## 3. SBOM

`sbom/`: one CycloneDX 1.5 JSON per crate, nine files. The firmware SBOMs are
generated for their real target: `thumbv6m-none-eabi` for `oasis-silicon-test`
(with `--features bootloaded`, as deployed), `oasis-bootloader` and
`oasis-mcu-demo`; `thumbv7em-none-eabihf` for `oasis-renode-m11`.

| SBOM | Components | Without licence |
| --- | ---: | ---: |
| oasis-rt | 54 | 0 |
| oasis-operator-key | 55 | 0 |
| oasis-secure-element | 55 | 0 |
| oasis-trl-harness | 57 | 0 |
| oasis-lora-transport | 55 | 0 |
| oasis-silicon-test | 127 | 0 |
| oasis-bootloader | 125 | 0 |
| oasis-mcu-demo | 108 | 0 |
| oasis-renode-m11 | 98 | 0 |

The files are kept exactly as generated. Path dependencies carry a local
`download_url=file://C:\dev\oasis\…` in their package URL; that is the build
machine's checkout, not a public location.

## 4. Limits

- An advisory database is a snapshot: these results hold for commit `ef6173c`.
  Re-run before any release.
- "No known vulnerability" says nothing about unknown ones; parser fuzzing (Phase
  2.3) and an external audit are separate steps.
- The SBOM lists crates, not the C toolchain, `rustc` or the RP2040 boot ROM.
- No CI job runs `cargo deny` / `cargo audit` yet. I cannot see this repository's
  Actions from here (no `gh`), so I have not added one I cannot watch run.
