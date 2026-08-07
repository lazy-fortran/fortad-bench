# Tapenade `nonRegressions/set01/lh050`

The fixed-form entry point is `sub0(x,y,z)`. It computes `u=x*y`, assigns
`z=3*u**2+x` and resets `u=2` when `x>0`, then overwrites `y` with `u*x`.
The original source has no `INTENT` declarations, so `z` is retained on the
`x<=0` path.

The exact source and stored tangent compile under strict F2018. Tapenade's
fresh parser and tangent also compile, but its fresh and stored reverse use
`INTEGER*4 branch` and are rejected by the strict compiler. FortAD accepts the
exact source and emits compilable forward and reverse modules; this is not a
success claim. Both exact transforms omit the conditional body in the
implicit-interface source and fail the independent oracle on `x>0`.

The bounded port in `port.f90` adds explicit `INTENT` declarations while
preserving the arithmetic and inout `z` behavior. Its FortAD forward transform
passes closed-form, central-difference, and adjoint checks. The bounded
reverse transform is generated but rejected because it assigns to `z_b` despite
declaring it `INTENT(IN)`. The runner records all of these gates, and the
Fortran harness requires the exact mismatch and bounded-forward pass.

Run the complete probe with:

```sh
FORTAD_REPO=/var/tmp/fortad-lh035-pinned-xQjiZj \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh050/run.sh
```
