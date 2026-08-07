# Tapenade `nonRegressions/set01/lh042`

`lh042` is a fixed-form declaration stress case for `decls1`. The exact
source uses declaration statements in an order rejected by strict Fortran,
nonstandard `INTEGER*8`, `INTEGER*16`, and `REAL*8` declarations, a derived
type array, COMMON storage, and EQUIVALENCE of dummy arguments. The stored
multidirectional output also includes `DIFFSIZES.inc`, which is absent from the
upstream case directory.

The exact primal and all four stored derivative/reference sources are checked
with strict fixed-form compiler flags. The independent compiler oracle
requires the corresponding diagnostics rather than merely checking that the
compiler exits nonzero. Fresh pinned Tapenade parser, tangent, reverse, and
multidirectional generation is also performed; every fresh generated source
is strict-compiled and fails on the same invalid-source boundary. Stored
derivatives are not used as fresh-generation evidence.

FortAD is run on the exact source in both forward and reverse modes. It
rejects the source while parsing the declaration order at line 10. This case
does not receive a bounded numerical port: changing declaration order, kind
syntax, dummy aliasing, or the absent include would invent semantics rather
than preserve the upstream regression.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh042/run.sh
```

The runner records the exact and fresh diagnostics, compiler statuses, source
hashes, generated-output hashes, and toolchain revisions in
`cases/tapenade-set01/lh042/result.txt`.
