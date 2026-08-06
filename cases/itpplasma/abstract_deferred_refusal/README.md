# Abstract deferred binding boundary

This case is a valid Fortran 2018 primal with an abstract base type, a
deferred type-bound function, a two-level override, and a factory that returns
an allocated polymorphic object. The two dynamic types have independent
closed-form values:

```
affine:  slope*x + bias
square:  curvature*x*x + slope*x + bias
```

The harness checks both models and a central finite difference of the primal.
FortAD is expected to refuse `model%value(x)`: dispatch through an abstract
deferred binding is not yet a supported derivative path. A refusal is useful
evidence here because silently differentiating only the base declaration would
be wrong. This is the P8.4/B2 boundary, not a claim of derivative support.

Run it with:

```sh
FORTAD_REPO=../fortad scripts/bench_itpplasma_oo_boundaries.sh
```
