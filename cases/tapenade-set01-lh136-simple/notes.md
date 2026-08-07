# Tapenade set01/lh136 simple tranche

This is the pinned lighthouse example.  The differentiable procedure
`eval_f` is a short tangent/trigonometric computation, but the exact source
also contains a fixed-form main program and an explicit `INTRINSIC TAN`
declaration.

Tapenade parses and generates all three modes, and every fresh output passes
the strict fixed-form syntax gate.  FortAD currently refuses the exact file
at line 30 while parsing the intrinsic declaration, so this record makes no
claim for a repaired or extracted procedure.

The independent oracle evaluates the `eval_f` equations directly and checks
finite differences at several nonsingular input points.
