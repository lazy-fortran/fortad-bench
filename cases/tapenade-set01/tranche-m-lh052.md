# Tapenade set01 `lh052`: strict-source refusal

`lh052` is a fixed-form, Fortran-only regression, but its unmodified primal
declares `aj` as a scalar in `COMMON /pandq/` inside `g` and subsequently
subscripts it.  A strict Fortran 2018 compiler rejects that contradiction;
there is consequently no conforming primal semantics to port or differentiate.

The runner uses the pinned Tapenade checkout to regenerate parser, tangent,
and adjoint output.  All three generated files retain the same invalid
subscripted `COMMON` declaration and fail the same strict compiler gate.  This
is an upstream-source refusal, not FortAD support: no repaired port, FortAD
transform, runtime result, or numerical oracle is claimed.

Run after fetching the pinned corpus:

```sh
TAPENADE_REPO=upstream/tapenade scripts/bench_tapenade_set01_lh052.sh
```

The reproducible record is
[`results/tapenade_set01_lh052_refusal_validation.txt`](../../results/tapenade_set01_lh052_refusal_validation.txt).
