# Kani — C9 (quorum orders), with parts J and K re-verified

**Run 2026-10-08, commit `b2d8e0b` on `positioning-alignment`.** Kani 0.68.0, CBMC 6.11.0,
WSL2 Ubuntu 3 381 MB. Clean `git` clone of the committed ref, **no stubs** — nothing in
these harnesses hashes or signs.

| | |
|---|---|
| Result | **12 verified, 0 refuted, 0 undetermined** |
| of which new for C9 | **5** |
| of which J/K re-verified | **7** — `REASON_COUNT` went 9 → 10 when C9 added `QuorumMissing`, and `proof_oas1_*` reaches `actuation_decision_ctx`, so re-running them was the point |

> ⚠️ **Correction to the commit message of `b2d8e0b`**, which says "6 Kani harnesses" for
> C9. It is **5** (178 − 173 = 5). The message is wrong and this file is right.

## The five C9 harnesses

| Harness | Proves |
|---|---|
| `proof_quorum_required_to_act` | **the invariant of C9**: for every input and every actuator state, `Act` implies `quorum_ok`. A critical order is never executed without a quorum |
| `proof_quorum_does_not_bypass_the_base_rule` | with a quorum present, `Act` still implies **all nine** base conditions, and the decision equals the ordinary rule's. A quorum is an extra gate, never a bypass |
| `proof_quorum_not_leaked_before_authorisation` | `QuorumMissing` is only ever returned to a sender that is already authentic **and** authorised — an untrusted sender learns nothing about the quorum policy |
| `proof_oaq1_parse_total` | the parser is total; length, reserved byte and signature count must all agree; `n_sigs == 0` is refused, so a quorum order can never be mistaken for an ordinary order lacking a quorum |
| `proof_oaq1_len_is_sane` | `oaq1_len` is monotone and cannot overflow for any accepted count, so a length check cannot wrap into accepting a short buffer |

## What is proved and what is tested

`quorum_ok` is a `bool` in the rule, for the same reason `v0b_ok` is: Ed25519 under CBMC
does not terminate on this machine. So the **rule** is proved and the **cryptography** is
tested, against the real `oasis_operator_key::OperatorAuthority`:

- one signature is not a quorum; the same operator twice is not two; an outsider twice is
  nobody; one insider plus one outsider is one;
- the signatures are over the order **body**, and a per-field loop asserts that changing
  **any** of the ten fields invalidates the quorum;
- the quorum is bound to the **network**, so one fleet's quorum cannot authorise another's.

That split is deliberate and stated rather than left to be noticed.

## Negative control — `neg/`

Two mutations, two named proofs, both **FAILED as intended**. The script aborts unless
every pattern matches exactly once.

| Mutation | Proof that must fail |
|---|---|
| the quorum check is removed from the rule | `proof_quorum_required_to_act` |
| `n_sigs == 0` is allowed, so a quorum order parses with no signatures | `proof_oaq1_parse_total` |

## What these proofs do not say

- **Nothing has run on silicon.** C9 has no firmware integration: no node holds an operator
  key **set**, and the k-of-n path was already "PC only" before this
  (`docs/KEY_LIFECYCLE.md` §7). So the two-person rule is implemented and proved, **not
  demonstrated on hardware**.
- **The size result is not a proof, it is arithmetic**, pinned by a test: a two-signature
  order is **343 bytes** on the wire against a 255-byte PHY limit, and even with one-byte
  signer indices and no setpoints it reaches **257** — two bytes over. The two-person rule
  **costs two frames**, and fragmentation (`OFR1`, silicon-proven phase 1.1) is how it
  travels.
- Carried public keys are **selectors, not authority**: membership in the authorised set is
  what `verify_authorization` enforces. The one-byte-index form needs the operator set
  provisioned on the node and is deferred.
- **Nothing here is a certified safety function** (no PL under ISO 13849-1, no SIL under
  IEC 62061).
