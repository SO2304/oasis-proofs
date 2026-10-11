# Kani — B1 (a signed order carried in MAVLink, arming only on `Act`)

**Run 2026-10-08, commit `e2e2045` on `positioning-alignment`.** Kani 0.68.0, CBMC 6.11.0,
WSL2 Ubuntu 3 381 MB. Clean `git` clone of the committed ref, **no stubs**.

| | |
|---|---|
| Result | **4 verified, 0 refuted, 0 undetermined** |
| Run 1 (`fe8cad9`) | **2 FAILED on an unwinding assertion** — inconclusive, not refutations. See [`run1/`](run1/) |

## The four harnesses

| Harness | Proves |
|---|---|
| `proof_no_arm_frame_without_act` | **the B1 invariant**: for every order, every actuator state and every class, a `COMMAND_LONG` exists **if and only if** the decision is `Act` |
| `proof_arm_implies_every_condition` | `Act` implies all ten Part F conditions **and** that the order named this vehicle with a binary `force`. The carrier does not weaken the gate |
| `proof_stop_class_never_arms` | an `OrderClass::Stop` never arms, whatever else holds, and gets the same reason as an out-of-limits order — it tells an attacker nothing |
| `proof_action_is_total_and_binary` | `action_of` is total and binary; a `NaN` `force` falls into the refusal |

The harnesses assert whether a frame **exists**, not what its bytes are: `encode_command_long`
allocates, and existence is the safety-relevant half. The bytes are covered by the tests,
which read them back with `parse_frame`.

## Negative control — `neg/`

Three mutations, three named proofs, all **FAILED as intended**. The script aborts unless
every pattern matches exactly once.

| Mutation | Proof that must fail |
|---|---|
| the `Stop` class refusal is removed | `proof_stop_class_never_arms` |
| a rejected decision builds the ARM frame anyway | `proof_no_arm_frame_without_act` |
| `force >= 1.0` counts as an arm, so the action is no longer binary | `proof_action_is_total_and_binary` |

## What these proofs do not say

- **Nothing has run on PX4 SITL.** The four B1 cases are covered by tests in software
  (`mo_*`, 7 tests over a real v0B envelope and a real `MeshRouter`), and the rule is
  proved here. "The drone arms" has **not** been demonstrated: PX4-Autopilot is no longer
  installed on this machine. That is half of B1 and it is open.
- **B1 serves segment S3 (drones), not the chosen S1.** It was done because phase 3 asks
  for it and the gate, counter and revocation are shared work — not as an investment in S3.
- The proofs say nothing about the **MAVLink carrier's parser**: `split_frame` and
  `extract_envelope` are covered by tests (including a per-byte corruption sweep and
  MAVLink 2 zero-truncation), not by a harness. A totality proof over a 254-byte payload
  was not attempted here.
- **Nothing here is a certified safety function** (no PL under ISO 13849-1, no SIL under
  IEC 62061).

## Reproducing

```
run_b1.sh positioning-alignment        # the four harnesses, on a clean clone
run_neg_b1.sh positioning-alignment    # the negative control; exits non-zero if any proof survives
```

⚠️ `run_b1.sh` prints "FAILED (counterexample)" for **any** `VERIFICATION:- FAILED`,
including an unwinding assertion, which is not a counterexample. That mislabel is what
made run 1 look like a refutation. It is a defect of the script, shared with the earlier
Kani campaigns in this repo.
