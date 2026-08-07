# Tapenade set05 `v052`

This tranche covers the scalar `test(x, i)` entry point from the pinned
Tapenade `nonRegressions/set05/v052` program.  The exact upstream program
also exercises elemental real and integer functions and a program driver;
the derivative contract is the real scalar `x` input and real scalar result.

The stored FortAD case is a standards-clean port of that same map,
`set05_v052(x, i) = 2*x + 2*i`, with the integer input retained as a
nondifferentiated argument.  Tapenade's fresh tangent and reverse outputs
make the same choice: only `x` receives a tangent or adjoint.

The runner compiles the exact upstream source and stored references, invokes
fresh Tapenade parser/tangent/reverse transformations, compiles every fresh
output under strict Fortran flags, generates FortAD JVP/VJP code, and runs an
independent hand JVP/VJP oracle with central differences and the adjoint
identity.
