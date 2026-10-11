# OASIS silicon re-run — corrected T0 / T4 / T5 (2026-10-06)

**Scope:** re-run of the three on-chip tests that an independent review of the
2026-10-04 run found to be *passing for the wrong reason* (or not measuring what
they claimed). Same three physical RP2040 clone boards (A / B / C), same USB-CDC
harness. **Every number below comes from a raw on-board log in this folder; none
is hand-entered.** Hashes in `SHA256SUMS`.

This does **not** supersede the 2026-10-04 evidence — it corrects three
test-quality defects in it. The crypto/R14/mesh *logic under test* was never
changed to make a test pass (that is a hard rule); only the **tests** were
corrected. See `../2026-10-04/REPORT.md` §13 for the erratum cross-reference.

---

## 1. What the independent review found (errata against 2026-10-04)

| Test | Defect in the 2026-10-04 version | Why it was wrong |
|---|---|---|
| **T0 clock** | Printed `PASS` with a hard-coded `clk=125000000Hz` taken from the config constant. | It never *measured* anything — it echoed the number it was configured with, so it could not have failed. |
| **T5 v9** | Tampered the **last byte** of the envelope and relied on the router dropping it. | The last byte is the inner payload, which v9's HMAC does **not** cover. The drop was actually `"duplicate"` (dedup), not `"bad mesh mac"` — a false positive: the MAC verifier was never exercised. |
| **T4 R14 gate** | Only counted how many high-signal faults were *blocked*. | No negative control: a gate that blocks *everything* would also score 50/50. Nothing proved it lets benign (low-signal) cases through. |

These are defects in **my** earlier tests, not in OASIS. The fixes below make
each test prove the thing it names.

## 2. The fixes (firmware `suite_main.rs.txt`, archived in this folder)

- **T0** — new `measure_core_hz()`: counts SysTick core cycles over a 100 ms
  `TIMER` window and compares the measured frequency to the configured one,
  `PASS` iff `|measured − cfg| ≤ cfg/100` (±1 %). Emits both numbers
  (`clk_cfg`, `clk_measured`). *Honest caveat:* both the SysTick reference and
  the TIMER derive from the same crystal, so this proves the PLL multiplier took
  effect (125 MHz, not the 12 MHz crystal), **not** crystal absolute accuracy.
- **T5 v9** — tamper a **MAC-covered** byte (`msg_id`), feed it to a **fresh**
  router (no dedup state), assert the drop reason is exactly
  `Drop("bad mesh mac")`. v0A likewise asserts `Drop("bad mesh signature")` on a
  forged signature. The verifier is now actually reached.
- **T4** — negative-control loop added: 50 high-signal faults must all block
  **and** a set of benign/nominal cases must produce **0** false blocks
  (`nominal_false_blocks`). `PASS` iff `blocked == 50/50 && false_blocks == 0`.

## 3. Re-run result — 3 boards × 3 runs = 9 logs, all green

`cargo build --release` per board → UF2 → BOOTSEL flash → `'r'` runs the suite.
Firmware git stamp baked into every line: `24cdbe3`.

**13 PASS / 0 FAIL on every one of the 9 runs.** Terminal marker
`OASIS|<id>|SUITE|PASS|done|end|24cdbe3` present in all 9.

### T0 — core clock actually measured (±1 % check, computed independently from the logs)

| board | clk_cfg | clk_measured | Δ | Δ% | tol (±1 %) | |
|---|---|---|---|---|---|---|
| A (×3) | 125 000 000 Hz | 124 998 600 Hz | 1 400 Hz | 0.0011 % | 1 250 000 Hz | OK |
| B (×3) | 125 000 000 Hz | 124 998 980 Hz | 1 020 Hz | 0.0008 % | 1 250 000 Hz | OK |
| C (×3) | 125 000 000 Hz | 124 998 980 Hz | 1 020 Hz | 0.0008 % | 1 250 000 Hz | OK |

Board A reads a *different* measured value (124 998 600) than B/C (124 998 980).
That per-board spread is the proof the firmware is genuinely measuring the clock
rather than echoing a constant.

### T4 — R14 gate with negative control (all 9 runs identical)

```
OASIS|<id>|T4|PASS|blocked=50/50,nominal_false_blocks=0/50,threshold=0.95|r14
```
50/50 high-signal faults blocked **and** 0/50 benign cases falsely blocked, on A, B, C.

### T5 — mesh tamper/forge rejection now reaches the verifier (all 9 runs)

```
OASIS|<id>|T5|PASS|v8_arrived=true,v8_dedup=true
OASIS|<id>|T5|PASS|v9_arrived=true,v9_tamper_rejected=true     (Drop "bad mesh mac")
OASIS|<id>|T5|PASS|v0A_arrived=true,v0A_forge_rejected=true    (Drop "bad mesh signature")
```
`v9_tamper_rejected=true` 9/9 · `v0A_forge_rejected=true` 9/9.

### T1/T2/T3/T6 (unchanged tests, re-confirmed on this run)

T1 ChaCha20-Poly1305 RFC 8439 ct+tag match + roundtrip; T2 X25519 RFC 7748
Alice+Bob; T3 Ed25519 KAT + verify + tamper-reject; T6 on-silicon timing
(soft-float RP2040): r14_fault ≈ 3.26 ms, v9_wrap ≈ 0.74 ms, v0A_sign ≈ 341 ms,
v0A_verify ≈ 176 ms (medians, K=5). All `PASS`.

## 4. What is still NOT tested (unchanged from 2026-10-04)

No LoRa / over-the-air radio (SX1262 driver is mock-tested only, never on
silicon). No energy budget, no secure element, no flight, no T8 flash
persistence. T0's clock check proves the PLL multiplier, not crystal accuracy.

## 5. Evidence files (hashes in `SHA256SUMS`)

`board_{A,B,C}_run{1,2,3}.log` (9 raw suite logs) ·
`firmware_{A,B,C}.uf2` (flashed images) · `suite_main.rs.txt` (corrected source).

## 6. Reproduce

```
# build (per board id A/B/C), flash the UF2 to the RPI-RP2 BOOTSEL volume
cd oasis-silicon-test
OASIS_BOARD_ID=A cargo build --release
elf2uf2-rs target/thumbv6m-none-eabi/release/oasis-silicon-test uf2/A.uf2
# capture (Git Bash; COM9 -> /dev/ttyS8): send 'r', read until the SUITE end marker
stty -F /dev/ttyS8 115200 raw -echo -ixon
exec 3<>/dev/ttyS8; printf 'r' >&3; while IFS= read -r -t2 -u3 l; do echo "$l"; case "$l" in *'|SUITE|'*'|end|'*) break;; esac; done
```
