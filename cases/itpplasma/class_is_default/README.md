# `CLASS IS` and `CLASS DEFAULT` JVP

`scaled_leaf_t` is a grandchild of `response_t` through the abstract
`scaled_response_t`. The `class is (scaled_response_t)` guard therefore accepts
the grandchild. Its sibling `fallback_response_t` reaches `class default`.

| Runtime arm | Primal | JVP |
|---|---|---|
| `CLASS IS` | `scale*x` | `scale*x_d` |
| `CLASS DEFAULT` | `x*x - 0.25` | `2*x*x_d` |

The leaf-only component is deliberately passive and unused. Run both advanced
cases with:

```bash
FORTAD_REPO=../fortad scripts/bench_itpplasma_polymorphism_advanced.sh
```
