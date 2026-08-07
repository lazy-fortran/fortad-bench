# Tapenade set01/lh144 simple tranche

The exact pinned source is a small call-chain regression: `top` calls `foo`
twice, then overwrites an intermediate before the final output assignment.
The case directory retains the source text byte-for-byte for provenance.

Tapenade generates and strictly compiles parser, forward, and reverse output.
FortAD generates a compiling forward module.  Its reverse module contains
`x_b` twice in the formal argument list when `x` is both an active input and
the selected output.  That is recorded as an expected FortAD refusal; no
repaired port is claimed.

The independent oracle evaluates the equivalent arithmetic and checks both
central differences and the VJP dot-product identity over several points.
