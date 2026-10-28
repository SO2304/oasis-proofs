# Encrypted agent-to-gateway link in front of the real Siemens LOGO! 230RCE, 2026-10-26/27
> Verdict summary only, written 2026-10-28. The raw traces, tools and code stay in the private repository; nothing here describes how the code works.

Successive builds of the encrypted link were each run three times against the real PLC: 27/27, then 31/31, then **35/35 checks per run**, plus the 15/15 baseline campaign each time. Authorised writes landed; refused orders left the PLC unchanged.

Limits: the encrypted segment was the local loopback in this topology; the PLC is an entry-level logic module.
