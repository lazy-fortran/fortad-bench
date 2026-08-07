# Tapenade set05 `v150` and `v168`

This tranche closes two previously unclassified pure-Fortran candidates from
the pinned Tapenade `nonRegressions/set05` checkout.  `v150` is the scalar
map `f=exp(t*t)`.  `v168` exercises two ABS-based dataflow steps; its port uses
a local temporary for the upstream overwritten intermediate while preserving
the dependent `y` map.

The exact upstream sources and stored Tapenade references compile with strict
Fortran flags.  The combined runner regenerates parser, tangent, and reverse
products with the pinned Tapenade executable, compiles every generated source,
emits FortAD JVP/VJP products for each standards-clean port, and runs the
independent hand derivative, central-difference, and adjoint-identity checks.
