# Hybrid key exchange between two real machines, direct Ethernet cable, 2026-10-26
> Verdict summary only, written 2026-10-28. The raw traces, tools and code stay in the private repository; nothing here describes how the code works.

**29 of 29 checks, three runs, both directions** (a Windows PC and a Linux PC, keys generated on their own machine, identity checked out of band). 1 200 honest exchanges gave the same secret on both machines every time. Altered ciphertexts and malformed inputs were refused, a replay was refused, and a key that had not been pinned was refused before anything was sent. Three negative controls of the test tool were each seen failing as intended. One full exchange costs 6.6 ms on this 10 Mbit/s link, about 1 ms of it computation: size, not computation, is the cost.

Limits: unauthenticated client in this test tool, no forward secrecy on the server side, a digest of each secret logged for the campaign only.
