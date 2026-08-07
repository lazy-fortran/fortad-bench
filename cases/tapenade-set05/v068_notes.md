# Tapenade set05 `v068`

`v068` is an invalid-upstream closure at the pinned Tapenade revision, not a
repaired derivative port. The exact `RUN::s(mb1,mb2,mb3)` source defines
`FUNC1(real(wp),integer)` and `FUNC2(real)`, then calls the generic with
`real(wp)` `mb1` and legacy `REAL*8` `mb3`. Neither actual has a matching
specific procedure. The stored `program_p.f90` preserves the same calls, and
`program_p.msg` records the `REAL*8` type mismatch.

Strict F2018 and legacy compiler controls both reject the unchanged exact and
stored sources at the generic call. Fresh pinned Tapenade parser, tangent, and
reverse products are generated, but all fail both compiler controls at the
corresponding `FUNC`, `FUNC_D`, or `FUNC_B` generic boundary. FortAD's exact
parser extraction succeeds; its forward and reverse probes refuse the generic
`FUNC` call and emit no derivative source.

No hand, finite-difference, or adjoint oracle is appropriate: changing the
generic interface or actual kinds would repair the source into a different
program. The independent oracle instead checks the exact source invariants and
reproduces the strict and legacy compiler refusals. Modern strict Fortran
boundaries remain explicit; no source is standardized or repaired.

Run from this repository root after building the pinned Tapenade checkout:

```sh
TAPENADE_REPO=/path/to/tapenade-at-e59864c \
FORTAD_REPO=/path/to/fortad-at-e790676 \
  cases/tapenade-set05/v068_run.sh
```

The reproducible measurement is [`v068_result.txt`](v068_result.txt).
