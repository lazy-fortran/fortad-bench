# Callback dispatch with `SELECT TYPE`

This is the supported replacement for the
[procedure-pointer case](../dynamic_callback_refusal/README.md). A polymorphic
callback object chooses one of two formulas while `x` remains the only active
input.

| Runtime child | Value | JVP |
| --- | --- | --- |
| `linear_callback_t` | `scale*x + shift` | `scale*x_d` |
| `quadratic_callback_t` | `curvature*x*x + tilt*x` | `(2*curvature*x + tilt)*x_d` |

The harness checks both generated results against hand JVPs and fixed values,
then times ten million dispatches. Run the paired boundary benchmark with:

```sh
FORTAD_REPO=../fortad scripts/bench_itpplasma_callback_boundary.sh
```
