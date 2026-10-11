# Kani — phase 2 parts G, H, I (authority hardening)

**Run 2026-10-07, commit `8926609` on `positioning-alignment`.** Harnesses for
`docs/AUTHORITY_HARDENING_SPEC.md` parts G (stop asymmetry), H (supervision liveness) and
I (decision journal).

| | |
|---|---|
| Result | **14 verified, 0 refuted, 0 undetermined** |
| Kani | 0.68.0, CBMC 6.11.0 |
| Host | WSL2 Ubuntu, **3 381 MB RAM**, 4 cores |
| Invocation | `cargo kani --lib --harness <name> -Z unstable-options -Z stubbing --harness-timeout 900s --output-format terse` |
| Source | clean `git` clone of the committed ref, **not** the Windows working tree (`run_hardening_harnesses.sh`) |

## Harnesses

| Harness | Proves |
|---|---|
| `proof_stop_never_blocked` | **the central invariant of part G**: for every input, authenticity + `STOP` + non-revocation ⇒ `Stop`. No other condition can refuse a stop |
| `proof_stop_requires_authenticity` | the converse: `Stop` only on those three, so an unauthenticated sender can never stop the machine |
| `proof_act_refused_while_stopped` | while the latch is set, no `Act` is possible, for any order |
| `proof_act_rule_unchanged` | **non-regression**: the 9-condition gate with the permissive context is identical to the 7-condition gate of part F |
| `proof_act_needs_live_supervision` | no `Act` without live supervision, whatever the order says |
| `proof_stop_ignores_supervision` | a dead supervision link never blocks a stop (part H must not undo part G) |
| `proof_supervision_bounded` | a beacon grants ≤ `MAX_SUPERVISION_MS`, never wraps into the past, `beacon_seq` strictly increasing |
| `proof_osb1_parse_total` | the `OSB1` parser is total; a parsed beacon re-encodes to its own bytes |
| `proof_order_class_total` | exactly two class bytes are accepted; an unknown class is refused, not defaulted |
| `proof_entry_roundtrip_is_lossless` | nothing in a journal entry is lost between struct and bytes |
| `proof_journal_seq_monotone` | `seq` advances by exactly one per append ⚠️ **under stub** |
| `proof_journal_parse_total` | the entry parser is total; a parsed entry re-encodes to the same 32 bytes |
| `proof_decision_byte_is_injective` | `Act`, `Stop` and the nine reasons never collide on one byte |
| `proof_every_decision_is_logged` | `append` has no path returning without an entry that records what was asked ⚠️ **under stub** |

## Two harnesses ran under a stub, and what that costs

`Journal::new` hashes through `genesis` and `Journal::append` through `chain`. A GOTO
program containing sha2 was **killed by the OOM killer at the instrumentation stage**,
before CBMC solved anything (`goto-instrument exited with status signal: 9`, "Trying to
force one backedge per target") — the same 3.3 GB wall as phase 1.2.

Both functions are replaced by cheap stubs (`genesis_stub`, `chain_stub`) in
`proof_journal_seq_monotone` and `proof_every_decision_is_logged`. **Those two therefore
prove sequencing and content preservation, not collision resistance.** The chain's
cryptographic behaviour is covered by tests instead, including
`jrn_every_byte_of_an_entry_is_chained`, which flips **every bit of every byte** of an
entry and requires each flip to break verification. That is a test, not a proof.

⚠️ A first attempt stubbed only `chain` and still died. The diagnosis was incomplete —
`Journal::new` hashes too — and the fix needed both. Recorded because the wrong first
answer is part of what happened.

## One refutation, and it was a real defect

The first run of `proof_journal_parse_total` came back **FAILED** on
`encode_entry(&e) == buf[..ENTRY_LEN]`. It was right: `ENTRY_LEN` is 32 but the fields
stop at byte 27, and only byte 27 was checked for zero — bytes 28..32 were a hole, so an
entry had **more than one encoding**. Fixed in `f123447` (all five reserved bytes must be
zero) and the test now loops over every one of them.

This is the same defect class `cargo-fuzz` found in `parse_oac1` in phase 2.3, hit again
while writing a format whose own module doc cites that lesson. The difference: a proof
caught it in **4.7 seconds**, before any fuzzing.

An earlier run, before `f38f42b`, returned 14 UNDETERMINED on a single **parse error** —
`assert!((b - DEC_REJECT_BASE) as usize < REASON_COUNT)` does not parse, because rustc
reads `usize <` as the start of type parameters. It compiled in every normal build because
the harness lives behind `cfg(kani)`, so the first Kani run was the first time the file
was ever parsed. A local syntax gate now exists:
`RUSTFLAGS="--cfg kani" cargo check -p oasis-rt --lib`.

## Negative control — `neg/`

Three mutations, each required to break one named proof. The script **aborts unless every
pattern matches exactly once**, because the phase 1.4 negative control was invalid when a
`sed` silently matched nothing after `cargo fmt` reflowed a line.

| Mutation | Proof that must fail | Result |
|---|---|---|
| a fourth condition that can refuse an otherwise valid stop | `proof_stop_never_blocked` | **FAILED as intended** |
| the stop latch no longer blocks an `Act` | `proof_act_refused_while_stopped` | **FAILED as intended** |
| only the first reserved byte is checked (the defect above) | `proof_journal_parse_total` | **FAILED as intended** |

So the three proofs bind: they are not vacuously true.

## What these proofs do not say

- They say nothing about **silicon**. Parts G, H and I have **no firmware integration, no
  flash persistence and no power-cut test** yet; the 10-test silicon plan is §4 of the spec.
- They say nothing about **SHA-256**. Collision resistance is assumed, never proved here.
- The journal is **tamper-evident against a remote attacker only**. On an RP2040, BOOTSEL
  or SWD rewrites entries and head together. The signed external anchor that would close
  that is specified in the spec and not built.
- **Nothing here is a certified safety function** (no PL under ISO 13849-1, no SIL under
  IEC 62061). `proof_stop_never_blocked` exists so that OASIS *cannot* disable a safety
  function — which is what keeps it outside the SRP/CS scope, not what puts it inside.

## Files

- `proof_*.log` — the 14 harness logs, one per harness
- `neg/proof_*.log` — the 3 negative-control logs
- `run_hardening_harnesses.sh` — the run script (clean clone, path guards, no `rsync`)
- `run_neg_control.sh`, `kani_neg_hardening.py` — the negative control
