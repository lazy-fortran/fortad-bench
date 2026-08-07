# Tapenade `nonRegressions/set01/ala05`

This case keeps the pinned exact source at
`upstream/tapenade/nonRegressions/set01/ala05`. The selected procedure is
`NFP(x,y)`, called by the exact `main` program. It performs 50 warm-started
fixed-point solves, increments `x` by `1.0/slices`, and accumulates `z/slices`
into `y`. The source's `1.0/slices` expression is default-real arithmetic; the
independent oracle preserves that detail.

The checked-in `Options` file is:

```text
-head "NFP(y)/(x)" -context -fixinterface
```

Pinned Tapenade parser, forward, and reverse commands all generate fresh
`.f90` and `.msg` files. Fresh parser and forward sources match their stored
references after removing only the historical Tapenade banner. Fresh reverse
output is intentionally not treated as byte-equivalent: current Tapenade uses
`ADSTACK_*REPEAT` calls, while the stored reverse uses `zbconv`. Both reverse
forms pass the legacy compiler gate and both are refused by strict F2018 for
`REAL*8 cumul`.

The unchanged exact source passes strict and legacy free-form syntax checks and
runs under gfortran. Its `y` value agrees with the independent Python model.
FortAD is exercised directly against that exact source. `check`, forward, and
reverse all refuse at the unsupported `DO WHILE` on line 27 and create no
output file. This is an expected refusal; no source repair or derivative port
is included.

`oracle.py` independently inventories the source shape, evaluates the 50-slice
recurrence, checks the exact primal result and iteration count, compares a
hand-derived JVP with a central difference, and checks a hand-derived scalar
VJP with the dot-product identity. It does not import, transform, or execute
Tapenade/FortAD output.

Reproduce the evidence from the bench root with:

```sh
./cases/tapenade-set01/ala05/run.sh
python3 cases/tapenade-set01/ala05/test_contract.py -v
```

The runner accepts `TAPENADE_REPO`, `FORTAD_REPO`, and `FC` overrides while
requiring the pinned revisions by default.

The evidence is pinned to FortAD commit `72ca2aa1c6c7d4b171b13a3e13c5190944080032`
and Tapenade commit `e59864c`. The runner enforces both revisions before
running the exact-source probes.
