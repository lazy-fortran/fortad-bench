# Tapenade `todoF90/REFERENCES/v420`

This small historical Fortran case is a two-stage scale operation:
`v = 5*u` followed by `v = 10*v`, so the active map is `v = 50*u`.
The unmodified upstream source, Tapenade tangent and adjoint output, and the
FortAD port are all compiled by the runner.  Hand JVP/VJP values, a four-step
central-difference sweep, and the JVP/VJP adjoint identity are independent
oracles.  Tapenade is invoked with `-root g` and its parser/generator output is
retained only as engine evidence; numerical correctness is checked against the
hand implementation.
