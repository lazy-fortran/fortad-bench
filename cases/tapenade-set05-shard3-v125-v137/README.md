# Tapenade set05 shard3 `v125` and `v137`

These two cases are promoted from the shard3 source-probe tranche after exact
source inspection. Fresh Tapenade parser, forward, and reverse products are
generated from the pinned upstream files and compiled with strict Fortran
2018 flags. FortAD transforms the standards-clean ports because the original
Tapenade interfaces use implicit function-result forms that do not provide a
checked derivative interface to FortAD.

`v125` differentiates `z = (x1-x2)*(y1-y2)`. `v137` differentiates
`s = x*y + x`. The independent oracle checks the hand JVP against central
finite differences and checks the VJP through the adjoint identity.
