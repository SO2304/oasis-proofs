# Run 1 (stamp `fe8cad9`) — FAILED on an unwinding assertion, not a counterexample

`first_run_console.txt` is the **console transcript** of the first run. The per-harness
logs of that run **no longer exist**: `run_b1.sh` starts with `rm -rf "$OUT"`, so the
re-run at `e2e2045` overwrote them. The transcript is what survives, and it is kept
because the result it records is worth not hiding:

```
=== proof_no_arm_frame_without_act
  *** FAILED (counterexample) ***
    Failed Checks: unwinding assertion loop 0
     File: "oasis-rt/src/mavlink_min.rs", line 229, in mavlink_min::crc_over
```

The script's own label — "FAILED (counterexample)" — is **wrong here**, and that is the
point. An *unwinding assertion* is CBMC saying it could not unroll a loop far enough; it
is not a property violation. `crc_over` loops over a 43-byte `COMMAND_LONG` frame and my
`#[kani::unwind(2)]` stopped it at 2. `unwind(64)` fixed it and all four harnesses verify
at `e2e2045`.

Two things to take from this rather than one:

1. **An unwinding assertion is inconclusive, never a refutation.** Reading the three
   words after "Failed Checks" is the whole difference.
2. **The runner script mislabels it.** It branches on `VERIFICATION:- FAILED` and prints
   "counterexample" either way. The same script produced the C9, J/K and hardening
   evidence, so the same mislabel could have appeared there — it did not, because those
   runs were green, but the script is wrong and this note is the record of it.
