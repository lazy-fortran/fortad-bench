# Tapenade set05 `v066`

`v066` is an invalid-upstream closure at the pinned Tapenade revision, not a
FortAD support claim.  The exact `TEST::FUNC` generic interface contains
specific procedures with identical real scalar type and rank that differ only
by array extent.  Fortran generic resolution cannot use that extent to
disambiguate `FUNC2` and `FUNC3`.  The selected `RUN::S` procedure then calls
the generic with 10x50 and 10x70 arrays, for which no specific procedure exists.
The stored `program_d.f90` repeats the same invalid interface in both `FUNC`
and `FUNC_D`.

Strict compilation rejects both exact sources.  Fresh pinned Tapenade parser,
tangent, and reverse outputs are generated, but all fail strict compilation
at the same generic-interface boundary.  FortAD's exact forward and reverse
probes refuse the unresolved generic call and produce no derivative source.

No hand/finite-difference/adjoint oracle is appropriate: changing the generic
overloads or the actual shapes would repair the source into a different
program.  The independent closure oracle instead checks the source invariants
and reproduces the strict compiler refusal for both exact files.

Run from this repository root:

```sh
TAPENADE_REPO=/path/to/tapenade-at-e59864c \
FORTAD_REPO=/path/to/fortad-at-253f59d \
  cases/tapenade-set05/v066_run.sh
```

The reproducible measurement is [`v066_result.txt`](v066_result.txt).
