# What the authority layer costs on a Modbus TCP link — 2026-10-08

Instrument: `oasis-rt/src/bin/bench_mbtcp_pilot.rs`. Host: Windows 11, loopback, release
build. K=10 rounds × 50 writes, each round reporting its own median; the band is the
half-spread over the 10 round medians, as a percentage of their median.

Reproduce:

```bash
cargo run --release --bin bench_mbtcp_pilot
```

## Result (`after_connection_reuse.log`, 3 runs, tree `b8e2513` + the pilot changes)

| arm | median | spread |
|---|---:|---:|
| 1 hop   HMI → PLC | 45–50 µs | ±15–24 % |
| 3 hops  HMI → 2 null relays → PLC | 142–176 µs | ±21–42 % |
| 3 hops  HMI → agent → gateway → PLC | **459–468 µs** | ±18–25 % |
| sign + verify + gate, no sockets | 257–278 µs | ±23–25 % |

**OASIS adds 286–317 µs** over the same three-hop shape, of which **257–278 µs is
sign + verify + gate**, leaving **29–39 µs** unaccounted — the journal append, the frame
being 153 B against the control's 12 B, the once-per-second clock refresh, and the
gateway's per-frame lock. The bench prints that residual itself and says so when it is
larger than half the crypto cost; it did, three times, during the work below.

## Why there are two null relays and not one

A relay with no OASIS in it measures what a middlebox costs whoever is in the middle. The
measured path has **three** hops — HMI → agent → gateway → PLC — so a single-relay control
has two, and the difference between them was charging OASIS for a loopback round trip it
did not cause. With the control chained to the same shape, OASIS's share dropped from
354 µs to ~300 µs and the residual from 95 µs to ~34 µs. The arms have to have the same
shape or the subtraction means nothing.

## The arc, and what the bench found

Every figure below was measured by this bench on this host. The first two columns describe
code that existed only in the working tree, so they are **recorded observations, not
reproducible artifacts**: only the last column reproduces from the tree.

| | connect per write | + connection reuse | + sequence lease (HEAD) |
|---|---:|---:|---:|
| HMI → agent → gateway → PLC | 3 172 / 3 853 / 4 093 µs | 915 / 876 / 907 µs | 468 / 460 / 459 µs |
| spread | ±6 % / **±724 %** / ±11 % | ±11 % / ±8 % / ±15 % | ±21 % / ±25 % / ±18 % |
| vs a direct write | 77–98× | 18–22× | ~10× |

Two defects were found by measuring, not by reading the code:

1. **A TCP connect per write, three of them** (agent→gateway for the clock, agent→gateway
   for the order, gateway→PLC). 2 867 µs of the first column's 3 131 µs of overhead was
   plumbing; only 264 µs was the authority layer. Worse than the median: one run banded at
   **±724 %**, because a connection per write also means thousands of ephemeral ports a
   minute. An unpredictable write latency is harder to live with than a slow one.
   Fixed by keeping all three links open, and by refreshing the gateway's clock once per
   second through part K's `TimeView` instead of once per write — whose safety property,
   already proven by Kani and on silicon, is that every error in a commander's clock view
   ends in a **refusal**, never an unintended execution.

2. **`fs::write` of the sequence file, per order.** After the first fix the bench still
   could not account for **628 µs** of an 887 µs overhead. One `fs::write` of that file
   measures **258 µs median** on this host (min 233, max 515) — as much as the entire
   sign + verify + gate. `SeqStore` now leases `SEQ_LEASE = 64` numbers per write, which is
   `tx_lease` from the MCU with the same guarantee: a crash loses up to 64 numbers and can
   never reuse one, because the file claimed them before any was handed out. The gate wants
   strictly newer, not consecutive.

## Limits

- **The PLC is a 30-line local responder, not `rmodbus` and not a PLC.** `rmodbus` is a
  dev-dependency and unavailable to a `[[bin]]`. The frame's correctness is proven against
  it elsewhere: `oasis-rt/tests/mbtcp_pilot_sockets.rs` (an `rmodbus` server on a socket,
  which reads back the ordered value) and phase 1.4 on three RP2040 against an independent
  device. What this bench measures is the **difference between arms through the same
  peer**; the absolute figures are a floor, because a real PLC adds its own response time
  and a real network adds a link.
- Loopback on one host. No radio, no RS-485, no field bus, and no second machine.
- Single-host Windows loopback is itself noisy: the one-hop arm bands at ±15–24 % on a
  45 µs median, so small differences between the first two arms should not be read closely.
- This measures **latency, not throughput**. The gateway serves orders one at a time (the
  state lock spans the PLC round trip), so a second HMI does not get a second pipeline.
