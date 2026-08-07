# Tapenade set01 tranche F

`lh049` is a dependency-free fixed-form regression with an in-place result.
The original `sub0` first computes `u=x*y`, writes `z=3*u**2+x`, then replaces
`u` with `2` and writes `y=2*x`. The port preserves that sequence with explicit
`real64` kinds and intents. The derivative contract treats the initial `x` and
`y` as independent and the useful scalar output as `z`. Final `y` is checked as
an additional in-place result.

For `z=3*x**2*y**2+x`, the hand derivatives are

```text
dz/dx = 6*x*y**2 + 1
dz/dy = 6*x**2*y
dy_final/dx = 2
dy_final/dy_initial = 0
```

The oracle point `(x,y)=(1.5,0.75)` is away from any singular or branch surface.
The runner compiles the unmodified upstream primal, forward reference, and
reverse reference with strict fixed-form flags (the stored references are
source-validity evidence only), generates FortAD JVP and VJP code, and checks
hand derivatives, a four-step central-difference sweep, and the JVP/VJP
adjoint identity. It records transformation, compile/link, runtime, memory,
and generated-source-size measurements.
