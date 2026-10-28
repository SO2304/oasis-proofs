# Hybrid post-quantum key exchange (ML-KEM-768 + X25519), 2026-10-26
> Verdict summary only, written 2026-10-28. The raw traces, tools and code stay in the private repository; nothing here describes how the code works.

| Check | Result |
|---|---|
| Test suite for the primitive | 10 of 10 pass, three runs, one commit |
| Published draft test vectors | reproduced byte for byte |
| Agreement with an independent implementation | 256 random draws identical, both directions; 500 round trips |
| Tampered ciphertexts | 1 344 altered, every outcome identical to the independent implementation |
| Negative controls | 11 introduced defects, all 11 caught |
| Cost, K=10, three runs | encapsulation 183–188 µs, decapsulation 195–213 µs |

Limits: the specification is an individual draft, not a standard. Nothing on silicon. The libraries are pre-1.0 and no external audit exists. Absolute timings vary with the state of the machine (the same code measured 225–276 µs earlier that day).
