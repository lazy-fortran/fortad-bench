# Tapenade `lh071`: duplicate/legacy syntax closure

`lh071` is represented twice in the pinned corpus.  The fixed-form
`nonRegressions/set01/lh071` source has `adj(a,b,c,d)` call `sub(a,b,c,d)`
after declaring `d(10)` in `adj` and scalar `d` in `sub`; strict compilation
rejects the call with a rank mismatch.  Its stored reverse reference repeats
the scalar/rank-1 mismatch for both `d` and `db`.  The same source also retains
obsolescent `COMMON` blocks and implicit interfaces, which are recorded as
legacy context rather than repaired.

The static queue classified both paths as `runnable-procedure-candidate` with
subroutine hints, while the batch/compiler inventory already recorded
`compiler-errors`.  The case preserves both rows and verifies the exact
source/reference files rather than promoting either static hint to support.

The free-form `nonRegressions/set03/lh071` source tests pointer assignments,
but its `x` and `y` dummy arguments are not declared `TARGET`.  Strict F2018
therefore rejects both `p => x`/`p => y`; the stored reverse reference has the
same defect for `pb => xb`/`pb => yb`.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds for
both roots, but every generated file retains the corresponding strict
compiler failure.  FortAD is run at both exact entry points in forward and
reverse modes: set01 stops at the `COMMON` declaration on line 4, and set03
stops at the unsupported pointer alias declaration on line 8.  No derivative
file is emitted.

This is classified as `expected-refusal-invalid-upstream`.  There is no
bounded port or derivative oracle: selecting an array element for `d`, adding
`TARGET`, or removing the legacy state constructs would test a repaired
program, not the exact corpus input.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh071/run.sh
```

The resulting strict-compile, fresh-generation, FortAD, diagnostic, and
source-checksum record is in [`result.txt`](result.txt).
