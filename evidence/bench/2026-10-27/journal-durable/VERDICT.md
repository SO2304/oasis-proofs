# Gateway decision journal: durable and faster, 2026-10-27
> Verdict summary only, written 2026-10-28. The raw traces, tools and code stay in the private repository; nothing here describes how the code works.

Per authorised write, HMI to device, loopback, held session, nine repetitions per build alternated three times: **1 905–2 116 µs with the journal**, against 6 315–6 692 µs for the previous build in the same session; 579–855 µs without the journal. The measured run's journal verifies intact. Three intermediate designs were refuted by adversarial review the same day and abandoned.

Limits: the drive has no power-loss protection and flush cost varies through the day, so only same-session comparisons count; no real power cut was applied (cuts were simulated in tests).
