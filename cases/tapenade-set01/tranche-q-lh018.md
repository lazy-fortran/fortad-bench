# Tranche Q: `lh018`

The exact regression composes an external function twice: the active path is
`a = f(b*c(10), d)` followed by multiplication with the constant `f(8*3.5,
4.5)`. The bounded port exposes the scalar result and the active `b` and `c`
inputs with explicit `real64` kinds. The original function mutates its second
argument, but that mutation is dead after each call; the port keeps the result
calculation while making the dead argument passive so FortAD can differentiate
the standard-conforming active dataflow.

The runner compiles the exact upstream primal and stored tangent/adjoint
references, regenerates fresh Tapenade parser/tangent/reverse outputs, and
strictly compiles them. FortAD forward and reverse outputs are checked against
the independent closed form `a_out = 343*b*c(10)`, a central-difference sweep,
and the JVP/VJP adjoint identity.
