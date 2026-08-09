# Abstract deferred binding boundary

This case is a valid Fortran 2018 primal with an abstract base type, a
deferred type-bound function, and a two-level override. The harness passes two
concrete child objects through the polymorphic dummy. The dynamic types have independent
closed-form values:

```
affine:  slope*x + bias
square:  curvature*x*x + slope*x + bias
```

The harness checks both models and a central finite difference of the primal.
FortAD supports `model%value(x)` when FortFront proves exactly one concrete
same-file implementation. This fixture deliberately contains both affine and
square children, so the dynamic target set has multiple possibilities and the
transform refuses rather than silently choosing one implementation. This is
the P8.4/B2 multi-target boundary; the one-child acceptance path is covered by
FortAD's independent abstract/deferred dispatch oracle.

The validation record
([`itpplasma_oo_boundaries_validation.txt`](../../../results/itpplasma_oo_boundaries_validation.txt))
records the FortAD commit used for the run and the precise refusal diagnostic
for multiple runtime targets. The fixture uses concrete local child objects,
so allocation lifetime is not an earlier refusal boundary.

Run it from the fortad-bench repository root with `../fortad` pointing to the
FortAD checkout:

```sh
FORTAD_REPO=../fortad scripts/bench_itpplasma_oo_boundaries.sh
```
