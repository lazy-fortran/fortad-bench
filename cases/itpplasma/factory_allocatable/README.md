# Factory-created polymorphic boundary

`make_profile` creates a `class(profile_t), allocatable` output using
`allocate(source=...)`. Both concrete profiles keep their coefficients in a
nested `coefficient_pair_t`. The primal harness checks both child values. The
FortAD derivative transform refuses this source at the allocation-lifetime
boundary until dynamic ownership can be replayed safely.

| Child | Primal |
|---|---|---|
| linear | `leading*x + trailing` |
| quadratic | `leading*x*x + trailing*x` |

The factory choice and coefficients are passive. Run the positive `CLASS IS`
case and this refusal boundary with:

```bash
FORTAD_REPO=../fortad scripts/bench_itpplasma_polymorphism_advanced.sh
```
