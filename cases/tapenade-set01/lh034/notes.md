# Tapenade `nonRegressions/set01/lh034`

`program.f` is a fixed-form bisection routine whose first argument is an
unresolved external function `F`. The pinned upstream directory contains the
primal, a forward reference (`program_d.f`), and `program_d.msg`; it does not
contain a stored reverse source. The message records that Tapenade needs a
differential for the external callback.

The exact primal and stored tangent compile with strict fixed-form Fortran
flags. Fresh pinned Tapenade parser and tangent output also compile strictly.
Fresh reverse generation succeeds, but its output does not compile strictly:
Tapenade emits nonstandard `INTEGER*4 branch` and then leaves `branch`
undeclared under `IMPLICIT NONE`.

FortAD refuses both exact modes at the source `RETURN` on line 23. This is an
exact-source boundary record; no support for the unresolved callback is
claimed.

The case-local `port.f90` resolves the callback to the explicit quadratic
`f(u) = u*u + 0.25*u` only as a bounded standard-conforming witness. FortAD
generates and compiles its forward transform. Its reverse mode correctly
reports that a branch inside a loop needs control-flow reversal. The hand
JVP/VJP, a central-difference sweep, and the JVP/VJP adjoint identity pass for
the fixed branch path exercised by the harness.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh034.sh
```

The runner builds or reuses only the pinned detached FortAD checkout needed by
this case and writes the reproducible result to
`results/tapenade_set01_lh034_validation.txt`.
