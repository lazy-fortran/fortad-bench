# Tapenade set12 profile tranche

This small tranche is selected from the completed source-probe evidence for
the pinned Tapenade revision. It contains one free-form function and one
fixed-form call primitive:

- `jlb012` is an exact-source expected refusal. Tapenade generates all three
  products, but its generated `REAL*4` declaration is rejected by the strict
  compiler; FortAD also emits an invalid function-result interface. The
  independent oracle still checks the mathematical sum map; it does not turn
  the refusal into support.
- `profile01` is runnable support. Fresh Tapenade parser, forward, and reverse
  products compile. FortAD's forward and reverse products compile and run
  against the hand, central-difference, and adjoint-identity checks.

The runner fetches no source and never edits the pinned checkout. Run:

```sh
scripts/bench_tapenade_set12_profile_tranche.sh
```

The result records the exact source hashes, engine revisions, diagnostics, and
all compile gates in `results/tapenade_set12_profile_tranche_validation.txt`.
