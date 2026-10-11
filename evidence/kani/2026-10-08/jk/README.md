# Kani — phase 2 parts J and K (compact stop, commander clock view)

**Run 2026-10-08, commit `46c62bb` on `positioning-alignment`.** Harnesses for
`docs/AUTHORITY_HARDENING_SPEC.md` part J (`OAS1`) and part K (`TimeView`).

| | |
|---|---|
| Result | **7 verified, 0 refuted, 0 undetermined** |
| Kani | 0.68.0, CBMC 6.11.0 |
| Host | WSL2 Ubuntu, 3 381 MB RAM, 4 cores |
| Invocation | `cargo kani --lib --harness <name> -Z unstable-options -Z stubbing --harness-timeout 900s --output-format terse` |
| Source | clean `git` clone of the committed ref, **not** the Windows working tree |
| Stubs | **none** — unlike the journal harnesses, nothing here hashes, so every proof ran against the real code |

## Part J — compact stop `OAS1`

| Harness | Proves |
|---|---|
| `proof_oas1_parse_total` | the parser is total; a parsed stop re-encodes to its own 11 bytes; the reserved byte is enforced, so a stop has exactly one encoding |
| `proof_oas1_equivalent_to_oac1_stop` | **the invariant that justifies dropping 43 bytes**: a compact stop and an `OAC1` class `Stop` with the same `actuator_id` and `cmd_seq` parse back to the same two fields and reach the same rule, which reads neither |
| `proof_oas1_addressing_is_total` | `actuator_id` 0 addresses **every** actuator and any other value addresses exactly one. A stop that silently addressed nothing would be the worst failure available here |

## Part K — commander clock view `TimeView`

| Harness | Proves |
|---|---|
| `proof_timeview_stamp_total` | `stamp`, `estimate` and `age_ms` are total: no overflow, no panic, including near `u64::MAX` |
| `proof_timeview_window_is_bounded` | **the invariant that makes part K safe**: whenever `stamp` yields a deadline, the window is at most `MAX_VALIDITY_MS` wide from the commander's own estimate, and the `boot_id` is the view's. A commander cannot build an order asking the gate for more time than the gate allows |
| `proof_timeview_refuses_stale_and_backwards` | a refusal has **exactly** one of three causes: local clock gone backwards, view older than `MAX_VIEW_AGE_MS`, arithmetic overflow |
| `proof_timeview_apply_is_monotone_within_a_boot` | a replayed beacon **changes nothing**; an accepted beacon either comes from another boot or advances the clock |

## Negative control — `neg/`

Three mutations, each required to break one named proof. The script **aborts unless every
pattern matches exactly once**, because the phase 1.4 control was invalid when a `sed`
silently matched nothing after `cargo fmt` reflowed a line.

| Mutation | Proof that must fail | Result |
|---|---|---|
| the reserved byte is no longer checked, so a stop has more than one encoding | `proof_oas1_parse_total` | **FAILED as intended** |
| `actuator_id` 0 no longer addresses every actuator, so a fleet stop addresses nothing | `proof_oas1_addressing_is_total` | **FAILED as intended** |
| a commander may ask for a window wider than the gate allows | `proof_timeview_window_is_bounded` | **FAILED as intended** |

So the three proofs bind; they are not vacuously true.

## What these proofs do not say

- **Nothing has run on silicon.** Parts J and K have no firmware integration: the J1–J6 and
  K1–K6 plans in the spec are **not executed**. In particular the claim that matters most
  for part K — that the PC never reads the actuator's clock — is **not yet demonstrated**,
  it is only made possible.
- `proof_oas1_equivalent_to_oac1_stop` says the two encodings are indistinguishable **to
  the rule**. It says nothing about the firmware dispatch routing `OAS1` to that rule; that
  is exactly what the silicon plan tests, and it is the same class of defect as `OSB1`
  missing from `content_kind` on 2026-10-08.
- Part K's safety argument — that every estimation error ends in a refusal — is proved only
  for the parts that are arithmetic. The two interesting directions (estimate too low, too
  high) are covered by a **test against the real gate**
  (`tv_estimation_errors_only_ever_refuse`), not by a proof, because they involve the
  actuator's real clock which no harness here models.
- **Nothing here is a certified safety function** (no PL under ISO 13849-1, no SIL under
  IEC 62061).

## Files

- `proof_*.log` — the 7 harness logs
- `neg/proof_*.log` — the 3 negative-control logs
- `run_jk_harnesses.sh`, `run_neg_jk.sh`, `kani_neg_jk.py` — the scripts, with their path
  guards
