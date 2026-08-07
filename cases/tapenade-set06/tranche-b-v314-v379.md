# Tapenade set06 `v314` and `v379`

This tranche closes two previously unclassified pure-Fortran candidates from
the pinned Tapenade `nonRegressions/set06` checkout.  `v314` differentiates
the active scalar map `x=y+z*z`; the upstream `eor` data table is local but
unused and is therefore omitted from the standards-clean callable port.
`v379` exercises a dynamic-shape input and the reduction `sqrt(sum(x)**2)`.
Its oracle uses positive-sum inputs, where the expression is smooth.

The exact upstream sources and stored Tapenade references compile with strict
Fortran flags.  Each runner invocation regenerates parser, tangent, and
reverse products with the pinned Tapenade executable, compiles every generated
source, emits FortAD JVP/VJP products for the port, and runs the independent
hand, finite-difference, and adjoint checks.
