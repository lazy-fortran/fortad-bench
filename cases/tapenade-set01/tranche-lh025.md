# Tapenade set01 `lh025`

The exact pinned source computes `Y = M^T M X`, where the first `N-K` rows of
`M` are `A` and the last `K` rows are `lambda I`. The exact primal and stored
single-direction tangent and reverse references are standard fixed-form
Fortran and compile strictly. The stored multidirectional reference also
compiles when the pinned `nonRegressions/DIFFSIZES.f` include is supplied.

Fresh parser, tangent, and reverse files are generated with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and strictly compiled. FortAD
refuses the exact source in both modes at its `RETURN` statement (line 73), so
the runnable FortAD comparison uses the bounded standard-conforming port.

The port keeps the dataflow unchanged for the bounded oracle instance
`N=7, K=3`, uses explicit `real64` kinds, and unrolls that fixed-size algebra so
the pinned FortAD revision can differentiate both modes. Its independent
oracle checks the direct JVP and VJP formulas, a central-difference sweep, and
the VJP/JVP adjoint identity for the full matrix, vector, and regularization
parameter. The fixed-size scope is recorded explicitly and is not presented as
a generic replacement for the exact source.
