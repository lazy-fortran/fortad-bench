# Tapenade `nonRegressions/set01/lh104`

This package closes the exact pinned upstream case
`nonRegressions/set01/lh104`. The source is fixed-form Fortran and contains
`top(a,b,c,d)`, which scales `a` and conditionally calls `S1(a,x)` for `b`,
`c`, and `d`. The source is retained by reference; no copy, intent annotation,
branch rewrite, runtime helper, or repaired port is included here.

## Pinned inputs

- Tapenade checkout: `e59864cab441d4175df75383b3ff58c3dcd26df9`
- FortAD checkout: `93f41d60d882778699ec1a887ce9a665a75afcf8`
- Exact files: `program.f`, `program_b.f`
- Entry point: `top(a,b,c,d)`

## Gate results

The exact primal `program.f` passes both strict F2018 fixed-form and legacy
syntax-only compilation. The stored reverse `program_b.f` passes the legacy
gate and refuses the strict gate because it contains nonstandard `INTEGER*4`
and leaves `branch` implicit under `IMPLICIT NONE`.

Fresh pinned Tapenade `-p`, `-d`, and `-b` runs all succeed. Fresh parser and
forward sources pass both compiler gates. Fresh reverse output reproduces the
stored reverse body and has the same boundary: legacy compilation passes while
strict F2018 compilation refuses it.

Exact FortAD probes use `--proc top`. `check` and forward mode emit
strict- and legacy-compiling free-form files. The reverse request uses
`--indep a,b,c --dep d`; FortAD emits a file, but the file fails both compiler
gates because the generated reverse sweep assigns to `d_b` after declaring it
`intent(in)`. The nonzero compiler gate is the expected refusal recorded by
this case. The generated file is not presented as supported derivative code.

## Independent oracle

`oracle.py` implements the piecewise real map independently of either
transformer. It checks both sides of the `a*3.8 = 10` branch boundary, a
central-difference directional JVP, and the VJP dot-product identity. These
checks describe the mathematical contract only; they do not turn the
oracle's model into a repaired upstream port.

`test_contract.py` contains exactly three contracts: the independent
behavioral oracle, fresh Tapenade generation with both compiler gates, and the
exact FortAD check/forward/reverse boundary. `run.sh` reruns the same evidence
and writes the pinned result record.
