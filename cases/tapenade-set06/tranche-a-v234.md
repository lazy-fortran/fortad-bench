# Tapenade set06 v234

This case promotes `nonRegressions/set06/v234` from the pinned Tapenade
checkout at `e59864cab441d4175df75383b3ff58c3dcd26df9`.

The exact upstream source is a strict-compiler-clean program containing the
small function `F(t) = t*t`. Tapenade can differentiate that program directly,
but FortAD's source lowering intentionally does not treat a contained function
inside a `PROGRAM` as a standalone differentiation entry point. The case
therefore uses the faithful callable port `set06_v234(t,f)`, preserving the
function's computation while making its input and output explicit.

The runner verifies exact upstream compilation, fresh Tapenade primal/tangent/
reverse generation and strict compilation, FortAD JVP/VJP generation and
compilation, and an independent hand-coded numerical oracle with central
differences and the adjoint identity.
