# Phase 2.1 on silicon — relay pre-filter against forced verification (C1)

Spec: `docs/specs/RELAY_PREFILTER_SPEC.md`. Gap: `partners/POSITIONING_GAPS.md` C1.

**Setup.** Two RP2040 boards, wired B.GP0 → C.GP1 (one way, 115 200 baud).
C = relay under test (terminal node), B = injector **and** legitimate origin. A was left
running the Phase 1.4 Modbus device and was not touched. One firmware, two modes
(`@O0` v0B / `@O1<next-hop fp>` v0C), same instrumentation, so before/after is measured
on one stamp. Logs are LF-only from USB-CDC; `harness/` holds the scripts, `artifacts/`
the signed manifests and image hashes.

Firmware installed through the **signed update path** (o2 hybrid manifests) at every
step: v6 → v7 (quiet mode) → v8 (link-key cache) → v9 (pre-signed legitimate frames) →
v10 (`@Y` legit rate) → v11 (insider model) → v12 (`@D` run-time budget) → v13
(interrupt-driven receive ring) → **v14, stamp `caef852`, which produced the results
below**. Earlier runs are kept and named `VOID_*` or superseded; §5 says why.

## 1. What a forged frame costs the relay

The C1 attack: anyone listening to the link can fabricate envelopes that pass every
cheap check (network, known origin, ttl, fresh counter) and force a full Ed25519
verification. Forged-only runs (`@Y<rate>,<secs>,0`) give an unambiguous per-frame cost:
30 s, no legitimate traffic, nothing lost on the wire (`crc_fails=0`).

| Mode | rate | frames | total busy | **per forged frame** | max |
| --- | ---: | ---: | ---: | ---: | ---: |
| **v0B (before)** | 1/s | 30 | 5.379 s | **179.3 ms** | 181.7 ms |
| **v0B (before)** | 2/s | 60 | 10.762 s | **179.4 ms** | 181.3 ms |
| **v0C (after)** | 1/s | 30 | 0.210 s | **0.70 ms** | 190.1 ms ¹ |
| **v0C (after)** | 2/s | 58 | 0.230 s | **0.70 ms** | 190.1 ms ¹ |

¹ The 190 ms maximum is the **first frame only**: it pays the one-off X25519 link-key
derivation (`dh_derivations=1`). Removing it gives (210 430 − 190 073)/29 = **702 µs**
and (230 090 − 190 105)/57 = **701 µs** — two independent rates agreeing to 1 µs.

**179.4 ms → 0.70 ms per forged frame, 256× cheaper**, plus 190 ms once per peer.
`busy_us` times only the `process*()` call, so it is free of logging and I/O.
Saturation by forged traffic alone moves from **5.6 frames/s** to ~1 400/s on CPU.

## 2. Availability under flood

8 forged frames/s **plus 1 legitimate message/s**, 60 s, v14 (interrupt-driven receive):

| # | Mode | Budget | Frames received | **Legitimate accepted** | Busy | Budget fired |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 70 | **v0B** | — | 371 / 539 | **39 / 60** (65 %) | 65.97 s (**110 %**) | — |
| 71 | **v0C** | 2/s, burst 24 | **539 / 539** | **60 / 60 (100 %)** | 11.34 s (19 %) | no |
| 74 | v0C, **insider** | none (10⁴/s) | 344 / 539 | 38 / 60 (63 %) | 61.53 s (**103 %**) | no |
| 72 | v0C, **insider** | 2/s, burst 24 | **539 / 539** | 4 / 60 (7 %) | 23.90 s (40 %) | **yes** |

**Against an outsider (the C1 attack), the pre-filter holds completely**: every one of
the 539 frames was received, `crc_fails=0`, all 479 forged frames refused at the tag,
and **all 60 legitimate messages delivered** with the relay 19 % busy. The budget never
had to fire — forged frames die at the tag, which is the design. In v0B the same traffic
left the relay at 110 % (still draining its backlog after the flood ended) and lost a
third of the legitimate messages.

**Against an insider**, the budget does what it was specified to do, to the token:
rate 2/s × 60 s + burst 24 = **144 tokens**, and the relay performed
139 verifications + 4 accepted = **143**. It keeps the relay alive — 103 % → 40 % busy,
344 → 539 frames received, 67 → 0 CRC failures.

**But it costs legitimate throughput: 38/60 without the budget, 4/60 with it.** The
budget is a **CPU cap, not a fairness mechanism**: it runs before the signature check, so
it cannot tell a legitimate frame from an insider's, and the insider takes the tokens
because it arrives eight times more often. The relay survives; the legitimate stream
starves. This is a property of the design as specified, not an implementation defect,
and it is the first thing to improve (for example reserving a share of tokens for
origins that verified successfully recently). **It must not be presented as protection
of availability against an insider.**

Also measured, with the budget set deliberately tight (`@D0,2`, burst 2, no refill) to
isolate the mechanism: an insider flood of 239 frames gave `drop_sig=2` and
`drop_budget=231` — exactly the burst reached the verifier, the rest were refused before
it, and the relay stayed at 2.3 % busy and received 233 of 239 frames.

## 3. What made this measurable

`v14` adds **interrupt-driven UART0 receive**: the Reader lives in `UART0_IRQ` (RXIM +
RTIM) and drains the hardware FIFO into a 4 KiB ring; the main loop pops from the ring.
Polling cannot capture bytes while the loop sits inside a 185 ms verification, so the
32-byte FIFO overran and the deframer lost sync — the relay saw 33 of 539 frames and
**zero** legitimate messages got through in both the capped and uncapped runs, which is
why this section previously said "inconclusive". With the ring, a busy relay **queues**
instead of losing, and the question becomes the one that matters: does the queue grow
without bound? It does in v0B (509–1286 bytes dropped from the ring, 63–67 CRC failures)
and it does not in v0C against an outsider (0 bytes dropped during run 71, 0 CRC
failures).

⚠️ `ring_dropped` / `ring_errors` are **lifetime counters since boot** — `@O` and `@D`
reset the per-run statistics but not these, so read them as differences between
consecutive runs on the same boot.

## 4. Figures

- Per forged frame: **179.4 ms → 0.70 ms** (256×); one-off 190 ms per peer for the DH.
- Relay load at 8 forged/s: **110 % → 19 %** (outsider).
- Legitimate messages delivered at 8 forged/s: **39/60 → 60/60** (outsider).
- Insider, with the budget: CPU bounded to 143 of 144 tokens, relay 40 % busy, no frame
  loss — but legitimate delivery drops to 4/60.
- Every figure is a single run, not a banded median.

## 5. Six defects this measurement found (all mine, all fixed)

Each would have produced a confident, wrong number. This is the part of the work that
took the time.

1. **Per-frame X25519** (`a8d97a2`). The first sweep measured **370 ms per frame** in
   v0C — *double* an Ed25519 verify, not a pre-filter. `process_v0c` derived the link key
   on every frame, and on a Cortex-M0+ an X25519 scalar multiplication costs about as
   much as the signature verification the filter exists to avoid. Fixed with `LinkKeys`,
   a no-alloc per-peer cache.
2. **The injector signed every forged frame** (`8dc1822`). It capped itself at 3.7/s when
   8/s was asked for and, worse, *accidentally paced* the traffic so the relay could read
   everything — while the later runs, with signing removed, sent catch-up bursts exactly
   when the relay was busy. The two halves of the comparison saw different traffic. Fixed:
   legitimate frames are signed before the timed loop and the schedule re-anchors.
3. **Two commands in one USB write** (harness). The firmware keeps a single line buffer
   per USB read, so `@O…` followed by `@S1` in one write silently lost the first: B stayed
   in v0B while C expected v0C and every frame was dropped as a downgrade. It depended on
   USB packet boundaries, so the runs before 10:50Z cannot be trusted. `pf_run.sh` now
   sends one command per write and verifies the mode on both boards.
4. **Polled receive** (`7f7a5ba`). See §3 — it made availability unmeasurable and hid the
   budget behind a receive limit of ~0.5 frames/s, far below the 2/s budget.
5. **A terminal node logged per frame** (`caef852`). A v0C node with no next hop logged
   `PF_NO_RESEAL` for every accepted frame; the host does not read that port during a
   run, so each log spun `Io::log`'s 400 000-iteration wait, blocked the main loop for
   seconds and overflowed the ring. Runs 61/62 showed a relay **4.7 % busy** that still
   lost 5 614 bytes — which read like a receive-path failure and was my own logging.
   Now counted, never logged per frame; the harness also drains C's port during a run.
6. **The budget was never exercised** until the insider model existed (`30dd63a`). Forged
   frames die at the tag, so `drop_budget` stayed 0 and I wrote that the insider half was
   untestable. The missing observation: the tag covers origin/counter/length/payload but
   **not the signature**, so any enrolled neighbour — which holds the link key by
   construction — can produce a frame with a valid tag and a broken signature. That is
   the insider, and it is cheap to generate.

## 6. Limits

- **Two nodes, one wired point-to-point link.** No radio; radio broadcast with N
  neighbours would need one tag per neighbour and is out of scope (TRL 6/7).
- **The budget does not protect legitimate traffic from an insider** (§2). It bounds CPU.
- **Single runs, not banded medians.**
- **The ring is 4 KiB** (~29 frames). A longer flood against a saturated relay still
  overflows it; that overflow is the correct signal, not an artifact.
- Kani covers the budget arithmetic and the v0C parser
  (`evidence/kani/2026-10-07/prefilter/`, 3/3 verified with a negative control). The
  ordering property — no Ed25519 without a valid tag, within budget — is not
  Kani-modellable through real X25519/HKDF/HMAC/Ed25519 and rests on the
  `ED_VERIFY_CALLS` counter tests plus these measurements.
- A stolen node still yields its own links' keys (flash is readable on an RP2040); the
  blast radius is one node, which is why per-link keys were chosen over a network key.
