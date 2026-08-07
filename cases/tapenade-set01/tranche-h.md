# Tapenade set01 tranche H: bounded `lh004` refusal

`lh004` is a dependency-free fixed-form regression whose `tata` routine
accumulates `abs(z)` and `y` in a loop controlled by the updated `x(1)`. The
ported primal uses a bounded 101-trip loop with the same guard, so its fixed
four-iteration trace is directly testable at `y=2.3` and `z=+/-0.7`.

FortAD forward mode emits compilable code for this trace. Reverse mode is an
intentional expected refusal: the current emitter reports
`a branch inside a loop needs control-flow reversal`. The runner records that
diagnostic exactly, compiles the pinned upstream primal and stored tangent and
adjoint references (the latter under legacy fixed-form mode), and checks the
ported primal against an independent hand JVP/VJP, four-step central
differences, and the adjoint identity. This is evidence for the next control-
flow milestone, not a support claim.

Run:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_h.sh
```

The result is recorded in
[`results/tapenade_set01_tranche_h_refusal_validation.txt`](../../results/tapenade_set01_tranche_h_refusal_validation.txt).
