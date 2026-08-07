# Tapenade set01 tranche G

`lh002` is a dependency-free fixed-form regression with a branch and two
nested calls to `sub1`. The positive branch writes `y=1.7`, updates `x` through
the call, scales `z`, and combines `y+z`; the negative branch computes
`y=3.3*x**2`. The final call writes `a=3.7*b`. The port keeps that sequencing
and exposes the final `x`, `y`, `z`, and `a` state as outputs. Initial `x`, `z`,
and `b` are the independent variables.

Away from the branch boundary, the hand derivatives are:

```text
x > 0:  dx_final = 5.1*dz, dy_final = 0, dz_final = 5.1*dz,
       da_final = 3.7*db
x < 0:  dx_final = dx, dy_final = 6.6*x*dx, dz_final = dz,
       da_final = 3.7*db
```

The focused runner compiles the unmodified upstream primal, forward,
multidirectional, and stored reverse references (the latter under legacy
fixed-form mode), generates and compiles FortAD JVP and reverse code, and
checks an independent hand JVP/VJP, four-step central differences on both
sides of the branch, and the JVP/VJP adjoint identity for `x_final`. It also
records transformation, compile/link, runtime, memory, and generated-source
measurements.
