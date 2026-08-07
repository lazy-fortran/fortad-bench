# Tapenade set04 `lh148` (`toto`)

This is one exact, standards-clean entry point from the pinned
`nonRegressions/set04/lh148/program.f90` source.  The directory also contains
`tata`, `titi`, and `tutu`; those are deliberately outside this promoted row.
The selected `module1::toto(a,b,c,d)` computes the scalar product
`d = a*b*c`, so its JVP and VJP have an unambiguous independent oracle.

The runner verifies the pinned Tapenade commit, the exact source/reference
SHA-256 values, and the clean FortAD checkout.  It then compiles the exact
source, generates fresh Tapenade parser/tangent/reverse products and compiles
all three under strict free-form flags.  Fresh FortAD forward and reverse
products are generated from the unchanged exact source, compiled strictly,
and executed through the case harness.  `oracle.py` independently checks the
closed-form JVP/VJP, a central-difference sweep, and the adjoint identity.

The stored `program_bv.f90`/`.msg` files are retained as hashed upstream
provenance; they are not substituted for fresh Tapenade generation.

Run it with:

```sh
FORTAD_REPO=/path/to/fortad-at-7f56c37 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set04/lh148/run.sh
```
