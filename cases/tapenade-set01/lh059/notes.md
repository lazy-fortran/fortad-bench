# Tapenade `nonRegressions/set01/lh059`

`lh059` differentiates the fixed-form routine `sub2(T,U,n,i)`.  The exact
primal, stored parser reference, and stored tangent compile with the strict
Fortran 2018 fixed-form gate.  The stored reverse fails at Tapenade's
nonstandard `INTEGER*4 branch`, and the stored multi-direction tangent fails
because `DIFFSIZES.inc` is not present in the upstream row.

Fresh pinned Tapenade parser, tangent, and reverse generation all succeeds for
the `sub2` root.  Fresh parser and tangent output compile strictly; fresh
reverse output has the same `INTEGER*4` refusal as the stored reverse.  Stored
derivatives are provenance only and are not treated as fresh-generation
evidence.

Pinned FortAD refuses both exact modes at the fixed-form label statement
`5 i =`.  The case therefore does not claim exact FortAD support.  The
case-local `port.f90` expresses the same `GOTO 5` state transition structurally
and specializes the reproducible probe to `n=31`, initial `i=6`, and its five
body iterations.  This path exercises both the `LOG` branch and the negative
`u(i)` path that skips `t(i)=3*u(i)`.  The bounded forward transform compiles
and agrees with the independent hand JVP.  Bounded reverse is attempted for
both outputs and records FortAD's control-flow-reversal refusal for a branch
inside the loop.

`oracle.py` independently evaluates the bounded primal/JVP, checks a central
difference sweep, and checks the bilinear adjoint identity by applying the
transpose of the hand-derived Jacobian.  `harness.f90` separately compares
the compiled bounded primal and generated JVP with `hand.f90`.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/var/tmp/fortad-lh035-pinned-xQjiZj \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh059/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
