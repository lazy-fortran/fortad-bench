# Tapenade set01 `lh055`

`lh055` is a short fixed-form callback case. The exact upstream routine
declares `REAL*8` and calls an external `TOTO` whose implementation and
differential are not present in the row. The stored scalar references repeat
the nonstandard declaration; `program_dv.f` additionally includes the absent
`DIFFSIZES.inc`.

With the pinned strict fixed-form compiler flags, the primal and every stored
reference refuse: scalar files fail on `REAL*8`, and the multidirectional file
fails at the missing include. Fresh pinned Tapenade parser, tangent, and
reverse generation succeeds (with Tapenade warning that `toto` is undeclared),
but all three generated files fail the same strict `REAL*8` gate. The stored
files are retained only as provenance; they are not fresh-generation evidence.

FortAD cannot make an exact transform from this legacy source: its exact
forward invocation reports that `b` is not declared in `TEST`, and exact
reverse reports that `a` is not declared. This is recorded as an exact-source
refusal, not silently repaired support.

The case-local `port.f90` is a bounded witness only. It makes the callback
semantics explicit as `toto(x)=x*x+0.25*x`, uses standard `real64` and explicit
`INTENT`, and keeps the one-call dataflow. Both FortAD forward and reverse
transforms compile and run. Their results are checked by the compiled harness
against an independent Python hand JVP/VJP, a central-difference sweep, and
the scalar adjoint identity. This bounded callback choice does not establish
support for arbitrary unresolved upstream `TOTO` implementations.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh055/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
