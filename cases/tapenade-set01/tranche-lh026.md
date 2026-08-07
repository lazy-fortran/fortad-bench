# Tapenade set01 `lh026`

`lh026` is a valid fixed-form Tapenade regression. Its `s1(a,b)` routine
updates an active array element and, when the updated `b(i)` was nonpositive,
adds two and jumps back to the label before the complete `i=1,100` sweep. The
stored forward reference preserves this restart; the stored reverse reference
also requires Tapenade's push/pop control-flow runtime and uses nonstandard
`INTEGER*4`.

The case keeps the exact upstream source in the pinned checkout. Its bounded
free-form port uses a 100-pass outer loop and a guarded inner loop to preserve
the restart trace without a nonstructured branch. The independent oracle uses
a separate structured reference primal, a hand trace-based JVP/VJP, a
directional central-difference sweep, component finite differences, and the
JVP/VJP adjoint identity. The selected inputs exercise two restart passes and
stay away from branch boundaries. The port is therefore a numerical oracle on
that explicit bounded contract, not a claim that arbitrary inputs needing more
than 100 restarts are covered.

The runner checks the exact primal and stored `program_d.f`, `program_b.f`,
and `program_dv.f` references under strict flags, using Tapenade's pinned
`nonRegressions/DIFFSIZES.f` include for the multi-direction source. It then
regenerates fresh parser, tangent, and reverse files with the pinned Tapenade
checkout. Fresh parser and tangent sources compile strictly; both stored and
fresh reverse sources reproduce the strict `INTEGER*4` refusal. FortAD forward
generation and compilation pass. FortAD reverse generation records the exact
control-flow refusal, and the independent harness passes.

The reproducible runner command is:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh026.sh
```

The reproducible record is
[`results/tapenade_set01_lh026_validation.txt`](../../results/tapenade_set01_lh026_validation.txt).
