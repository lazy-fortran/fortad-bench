# Tapenade set01/lh060 evidence

## Classification

`expected-refusal-with-bounded-forward-port`.

The pinned upstream source is a fixed-form `INVERT` routine. It keeps `TN` in
the hidden `/ls0001/` COMMON block and passes opaque `FX3` and `FX4` procedure
arguments. The source itself has no concrete callback semantics to preserve in
a numerical derivative oracle. The stored reverse and multidirectional files
also include `DIFFSIZES.inc`, but that include is absent from the upstream
`lh060` directory.

The exact source is therefore kept as a refusal boundary. A bounded,
standard-conforming specialization in `port.f90` exposes the state and fixes
small explicit callback contracts while retaining the `FX3`, `FX4`, `FX3`
call sequence. It is deliberately not promoted to exact-source support.

## Reproduction

From the repository root, with the pinned checkouts available at
`upstream/tapenade` and `../fortad` (or with `TAPENADE_REPO` and
`FORTAD_REPO` set), run:

```bash
cases/tapenade-set01/lh060/run.sh
python3 cases/tapenade-set01/lh060/test_contract.py
```

The runner uses these strict compiler flags for both the fixed-form upstream
files and generated fixed-form Tapenade output:

```text
-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface
```

It runs pinned Tapenade commands:

```text
tapenade -p -O . -o lh060 nonRegressions/set01/lh060/program.f
tapenade -d -root invert -O . -o lh060 nonRegressions/set01/lh060/program.f
tapenade -b -root invert -O . -o lh060 nonRegressions/set01/lh060/program.f
```

It then checks exact FortAD forward and reverse diagnostics, generates a
bounded JVP and one VJP for each explicit output, compiles every generated
artifact, and runs the Fortran harness. `oracle.py` is independent of FortAD:
it hand-propagates the bounded algebra, checks a central-difference sweep,
and checks the VJP/JVP adjoint identity.
