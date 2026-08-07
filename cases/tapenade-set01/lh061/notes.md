# Tapenade `nonRegressions/set01/lh061`

`lh061` is a fixed-form callback boundary.  The exact routine has one
operation, `CALL PJAC(Y,JAC)`, and declares `F`, `JAC`, `PJAC`, and `SLVS` as
external procedures without supplying any of their bodies or derivative
rules.  The legacy implicit `REAL` declaration of `Y` is accepted by a strict
Fortran compiler, but it is not an explicit FortAD input declaration.

The exact source and stored parser, tangent, and reverse references compile
with the recorded strict fixed-form flags.  The stored multidirectional
reference is the one exception: it includes `DIFFSIZES.inc`, which is absent
from this upstream row.  Fresh pinned Tapenade parser, tangent, and reverse
generation succeeds and each fresh single-direction output compiles strictly.

FortAD is probed on the unmodified exact source with `Y` as the active
in-place input/output.  Both modes refuse before emission because the active
`Y` dummy is implicit and therefore not declared in the parsed procedure.
Adding an explicit declaration alone would still leave `PJAC` opaque; a
semantics-preserving derivative requires a user-provided rule for the missing
callback.  The upstream row supplies neither that rule nor callback bodies.

Consequently this case has no bounded numerical port, hand JVP/VJP oracle,
central-difference sweep, or adjoint identity.  Inventing `PJAC`, `JAC`, or
their derivatives would test a different program.  The independent
case-local oracle reproduces the compiler acceptance/refusal boundary instead.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/path/to/fortad-at-0e15604 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh061/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
