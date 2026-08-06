# Factory-created polymorphic JVP

`make_profile` creates a `class(profile_t), allocatable` output using
`allocate(source=...)`. Both concrete profiles keep their coefficients in a
nested `coefficient_pair_t`. The generated JVP receives the allocated base-class
object and reads those nested components inside `SELECT TYPE`.

| Child | Primal | JVP |
|---|---|---|
| linear | `leading*x + trailing` | `leading*x_d` |
| quadratic | `leading*x*x + trailing*x` | `(2*leading*x + trailing)*x_d` |

The factory choice and coefficients are passive. Run both advanced cases with:

```bash
FORTAD_REPO=../fortad scripts/bench_itpplasma_polymorphism_advanced.sh
```
