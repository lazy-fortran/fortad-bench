# Tapenade `nonRegressions/set01/lh072`

`lh072` is a fixed-form callback regression.  `top(A,B)` first updates every
`A(i)` with `B(i)*A(i)`, then calls `TOTO(EXTF,B)`, which reaches `EXTF` through
`TUTU` and squares `B(4)`, and finally calls `EXTF(B(10))`.  The callback is
defined in the same upstream file; there is no license to invent a different
external routine or derivative.

The exact primal, parser, tangent, and reverse references compile under the
strict fixed-form gate.  The stored multidirectional reference is the one
exception: all four routines include `DIFFSIZES.inc`, and that file is absent
from the pinned `lh072` directory.  Fresh Tapenade parser, tangent, and
reverse generation from the pinned checkout succeeds, and each fresh output
compiles strictly.

FortAD's exact forward and reverse probes at `top` stop at the same callback
boundary: inlining `toto` would require a statement form the current emitter
does not support.  This is recorded as an expected exact-source refusal.

The case-local `port.f90` specializes the known callback body while retaining
the two callback applications and their update order.  It makes the state
arrays explicit and adds `a_sum`, the sum of final `A`, solely to give reverse
mode one scalar dependent.  The bounded reverse result is therefore a
derivative of that explicit observation, not a claim that FortAD supports the
original callback-passing source or an array-output reverse contract.

`hand.f90` supplies independent formulas.  `oracle.py` checks the callback
values, a central-difference sweep, and the JVP/VJP adjoint identity in
double-precision Python arithmetic.  `harness.f90` compiles and runs the
bounded primal, FortAD forward, and FortAD reverse outputs against those
formulas.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh072/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
