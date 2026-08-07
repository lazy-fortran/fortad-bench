# Tapenade set05 `v069`

`v069` is an invalid-upstream closure at pinned Tapenade revision
`e59864c`, not a repaired derivative port. The exact `RUN::s(mb1,mb2,mb3)`
source declares `FUNC2` and `FUNC3` as `ELEMENTAL` while both procedures use
`PRINT`. Since an elemental procedure is implicitly pure, strict and legacy
gfortran reject the exact source. Strict mode also rejects its `REAL*8`
declarations. The stored tangent source fails the same purity boundary and its
stored message records a `TC30` mismatch for the `REAL*8(3)` generic call.

Fresh pinned Tapenade parser, tangent, and reverse products are generated, but
all fail strict and legacy compilation at the same purity boundary. FortAD at
`a41afde` refuses parser, forward, and reverse probes at the generic call and
emits no derivative source. The independent oracle therefore checks exact
source invariants and compiler refusals; no hand, finite-difference, adjoint,
or numerical derivative oracle is appropriate for an invalid source.

Run from this repository root after preparing the pinned checkouts:

```sh
TAPENADE_REPO=/path/to/tapenade-at-e59864c \
FORTAD_REPO=/path/to/fortad-at-a41afde \
  cases/tapenade-set05/v069_run.sh
```

The reproducible measurement is [`v069_result.txt`](v069_result.txt).
