# Encrypted link between two real machines, cable and Wi-Fi, 2026-10-27
> Verdict summary only, written 2026-10-28. The raw traces, tools and code stay in the private repository; nothing here describes how the code works.

**Cable: 227 of 227 checks, three runs. Wi-Fi: 215 of 215, three runs.** Offline negative controls 22/22, three runs each. Legitimate traffic only. A passive relay recorded the connections: no plaintext marker appeared on any of the five recorded connections, while the pre-encryption control runs showed them all; the public key and ciphertext differed on every connection. Cost on the cable: nothing measurable per write on an open session (paired differences −0.04 to +0.39 ms, below noise); +2.2 to 5.0 ms per new connection.

Limits: the device was the simulator, not the PLC; no link refusal was provoked between the two machines; the client is not authenticated; handshake, frame sizes and timing remain visible, as do the two clear-text Modbus segments at either end.
