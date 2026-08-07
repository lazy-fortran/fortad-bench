# Tranche N: `lh085` and `lh092`

This tranche closes two adjacent pure-Fortran rows from Tapenade's pinned
`nonRegressions/set01` corpus:

- `lh085` exercises large-expression splitting, array-element products, and
  nontrivial powers. The port keeps the full primal but uses `v` as the active
  input and `r1` as the scalar dependent for the numerical contract; the
  other outputs are still compiled and checked by the generated procedure.
- `lh092` exercises a nested call and the type of temporaries introduced by
  splitting. Its port inlines the two-line `f2` body while preserving the
  `f1` value, and checks both `a` and `b` in forward and reverse mode.

Run the pinned upstream probes and the FortAD oracle with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh083_096.sh
```

The runner compiles the exact upstream sources, fresh Tapenade parser/tangent/
adjoint outputs, and all generated FortAD sources. The executable checks
independent analytic JVP/VJP values, a central-difference directional sweep,
and the JVP/VJP adjoint identity.
