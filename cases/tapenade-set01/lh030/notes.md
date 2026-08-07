# Tapenade set01 `lh030`

`lh030` differentiates `head(i1,i2,o)`, which calls two square-root
subroutines and combines their results as `o = (z1-z2)/(1+z1+z2)`.
The original fixed-form source carries `zn` and `zd` through `COMMON /zz/`.
Its stored parser, tangent, reverse, and multidirectional references are
present in the pinned Tapenade checkout, and the runner compiles all of them
with strict fixed-form Fortran flags.  `program_dv.f` is compiled with a
temporary `DIFFSIZES.inc` link to the pinned `nonRegressions/DIFFSIZES.f`.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds, and
each generated file strictly compiles.  FortAD rejects both exact-source
directions at the `COMMON /zz/` statement on line 2.  This is recorded as an
exact-source boundary rather than silently treating COMMON state as a local
variable.

The case includes a bounded standard-conforming port.  The port keeps the
same numerical chain while representing `zn` and `zd` as local temporaries;
the root routine is written directly because the pinned FortAD inliner does
not transform the original call structure.  The case runner generates both
FortAD products for that port, strictly compiles them, and runs a harness
containing an independent closed-form JVP/VJP, central finite differences,
and the adjoint identity.  The oracle samples nonzero inputs in the smooth
domain, avoiding the source's explicit `t == 0` branch in `g(t)=sin(t)/t`.

Run from the repository root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh030/run.sh
```

The reproducible record is [`result.txt`](result.txt).
