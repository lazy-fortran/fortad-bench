# Tapenade `nonRegressions/set01/lh067`

`lh067` is a fixed-form legacy function, `read7(z)`, whose successful path
computes a value after a formatted input read:

```fortran
ncmax = 10
read(...,err=31,end=30)nmai
read7 = z
ncmax = z + ncmax
read7 = ncmax*z
```

The exact primal compiles under the recorded strict fixed-form flags only
because its undeclared I/O units and variables receive legacy implicit types.
The stored parser, tangent, and reverse references add `IMPLICIT NONE` but omit
`nfic12`, so each refuses.  The stored multidirectional reference also
includes the absent `DIFFSIZES.inc`.  Fresh pinned Tapenade parser, tangent,
and reverse generation succeeds, but all three generated files reproduce the
undeclared-`nfic12` strict-compile refusal.

FortAD exact forward diagnoses the unsupported `READ` syntax, then emits a
procedure with empty arguments that fails independent strict compilation.
Exact reverse refuses because the function result `read7` is not a declared
dummy.  The forward zero exit is therefore recorded as an unusable generated
output, not as exact support.

The case-local `port.f90` is a bounded normal-read-path witness.  The read has
no computational effect when it succeeds, and for the probe interval
`1 < z < 2`, the original integer assignment `ncmax = z + 10` produces 11.
The port specializes that local behavior to `read7 = 11*z`; this avoids
assigning a fictitious derivative to the integer conversion.  The upstream
error/end branches are intentionally excluded because the source leaves the
function result undefined there through implicit legacy state.  Both bounded
FortAD forward and reverse transforms compile and run, and their values are
checked by the compiled harness against an independent hand JVP/VJP, a
central-difference sweep, and the scalar adjoint identity.  This bounded
normal-path result is not promoted as exact support for the original I/O
routine.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh067/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
