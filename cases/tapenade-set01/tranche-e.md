# Tapenade set01 tranche E

`lh001` is a fixed-form two-subroutine regression. `top` calls `sub1`, then
overwrites `i1` and `i2`, replaces `o3` with `2`, and scales `o1`. The port
keeps that sequencing and state mutation, with explicit `real64` kinds and
intents. For differentiation, the initial independent state is
`(i1,i2,i3)` and the useful scalar output is `o1`. The other outputs are
constant checks (`o2=35`, final `o3=2`).

At the oracle point `(i1,i2,i3)=(4,1,2)`, the denominator `i1-3*i2=1` is away
from its singular surface. The independent hand derivative is

```text
o1 = 35*i1*i2**2/(i1-3*i2)
do1/di1 = -105*i2**3/(i1-3*i2)**2
do1/di2 = 35*i1*i2*(2*i1-3*i2)/(i1-3*i2)**2
```

The runner compiles all five pinned upstream source/reference files (the
stored reverse reference uses legacy fixed-form syntax), then generates and
compiles FortAD forward and reverse code. It checks the hand JVP/VJP, a
four-step central-difference sweep, and the JVP/VJP adjoint identity before
recording timing, memory, and generated-source sizes.
