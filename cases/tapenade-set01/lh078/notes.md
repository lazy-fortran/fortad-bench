# Tapenade set01/lh078

`lh078` is the fixed-form `testPower` regression under the pinned Tapenade
checkout.  The exact source is intentionally retained through the upstream
path; no local copy, cleaned source, bounded port, or synthetic root is added.

The source is not a valid strict Fortran translation unit: its first
`SUBROUTINE` statement ends with a C-style `{`.  The stored Tapenade parser,
tangent, and reverse references are fixed-form outputs, but their `REAL*8`
declarations fail the strict F2018 pedantic gate.  The stored multidirectional
reference also depends on the absent `DIFFSIZES.inc`.  Fresh pinned Tapenade
parser, forward, reverse, and multidirectional probes reproduce generated
artifacts and the strict `REAL*8`/missing-include refusals.

FortAD is tested against the exact upstream source at commit
`7adc75030db3fa4422339d82d2725ae29ee13dac`.  With the source variables that
FortAD can resolve (`x,y`, output `r`), forward mode writes a derivative, but
the result fails strict compilation because the exact source's `x8/y8/r8`
state is not declared in the generated free-form procedure.  Reverse mode
refuses the exact source at the first `r8` assignment and writes no output.
This is recorded as a reproducible boundary, not as exact support.

The standalone Python oracle checks the arithmetic represented by the source
for positive inputs while treating the source's read-before-write values
`r(3)`, `c(1)`, and `c(3)` as explicit state.  It independently checks a
hand-derived JVP against central differences and a reverse dot-product
identity.  It does not claim that the undefined original state has been
repaired or that the invalid source has a numerical port.
