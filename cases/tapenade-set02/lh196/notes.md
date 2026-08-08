# Tapenade set02 `lh196`

`lh196` is the pinned fixed-form polygon-cost debug regression.  The exact
source contains a complete `MAIN` program and the callable `POLYCOST` path:
`POLYCOST` calls the external function `POLYPERIM`, which accumulates edge
lengths through `INCRSQRT`'s in-place result argument.  `POLYSURF` computes the
signed polygon area.

The exact primal and stored tangent/reverse references use legacy `REAL*8`.
They pass the legacy fixed-form compiler gate and fail strict Fortran 2018 at
that extension.  Fresh pinned Tapenade parser, tangent, and reverse products
show the same compiler boundary.

FortAD at `ac8d04b` refuses the exact check, forward, and reverse requests at
the `POLYPERIM` call: `inlining POLYPERIM would need a statement form it does
not have`.  No generated FortAD source is emitted.  This case therefore does
not add a modernized source, a bounded derivative port, or a support claim.

The independent Python oracle models the exact polygon-cost arithmetic from
the source text and checks primal values, a closed-form JVP, central
differences, and the VJP dot-product identity.  It is a semantic measurement,
not a replacement source for FortAD.

Run from the bench root with the pinned checkouts, for example:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set02/lh196/run.sh
```
