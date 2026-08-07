# Tapenade `nonRegressions/set01/lh044`

`lh044` is an invalid-upstream closure at the pinned Tapenade revision. The
fixed-form entry point is `invert(FX0,FX1,X,A0,B0,N,FX2,FX3)`. It declares
`FX1` as both a dummy argument and `INTRINSIC`, which a strict Fortran
compiler rejects. The other callbacks are unresolved external procedures,
and the calls also pass the character literal `"coucou"` through implicit
interfaces.

The pinned directory contains the primal, parser, tangent, reverse, and
multidirectional stored references plus their Tapenade message files. The
multidirectional source uses the pinned `DIFFSIZES.inc` include supplied by
the Tapenade non-regression tree. Strict compilation of every exact stored
source fails with the independent compiler diagnostic `DUMMY attribute
conflicts with INTRINSIC attribute`.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds. Each
fresh generated Fortran file reproduces the same strict compiler failure; the
fresh files are never substituted for the stored references. FortAD is
probed on the exact source in forward and reverse modes and refuses both at
line 5, the `INTRINSIC FX1` declaration.

No bounded numerical port is included. Removing the conflicting declaration
or inventing definitions and derivatives for `FX0`, `FX2`, `FX3`, and
`FXlocal` would change the upstream program. The case-local Python oracle is
therefore a compiler/diagnostic contract, and the runner separately records
the fresh Tapenade and FortAD gates.

The case-local fixed-form harness.f is a minimal diagnostic witness for the
same dummy/intrinsic conflict. It is compiled expecting the same independent
compiler error; it is not presented as a repaired implementation or a
numerical oracle.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/path/to/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh044/run.sh
```

The reproducible record is [`result.txt`](result.txt).
