# Tapenade set01 tranche I: `lh019` AA-type components

`lh019` is the corpus regression for Tapenade's `-associationByAddress`
Fortran 2003 dual type. The upstream checkout contains the fixed-form primal,
the `AATypes_aad/aab` modules, and generated forward/reverse references. The
runner compiles those files under strict GNU Fortran modes before exercising a
small, source-equivalent scalar kernel with a concrete `real8_diff` value.

The port keeps the active algebra and branch: for `n >= 5`,
`output = x%v*y%v`; for `n < 5`, it is the pass-through `x%v`. The integer
`tag` field demonstrates that inactive derived components remain passive. The
independents are named components (`x%v`, `y%v`), not whole objects. FortAD
generates both JVP and VJP shadows with ordinary component syntax.

The focused runner checks the generated routines against an independent hand
JVP/VJP, four central-difference steps on both branches, and the adjoint
identity. It records transform, compile/link, runtime, memory, and generated
source sizes:

```bash
TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_i.sh
```

The upstream `program.f` itself is a mutable array kernel. This bounded port
isolates its AA-type active-component contract; array-valued derived objects
and active in-place component updates remain separate roadmap work.
