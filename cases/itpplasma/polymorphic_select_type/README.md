# Runtime-selected field JVP

This case follows the structure used by KAMEL's KIM factory and rabe's field
hierarchy: an abstract base reaches one of two concrete field models at runtime.
The active kernel selects the dynamic type.

For a direction `x_d`, the two hand derivatives are:

| Child | Primal | JVP |
|---|---|---|
| `linear_field_t` | `scale*x + offset` | `scale*x_d` |
| `quadratic_field_t` | `curvature*x*x + tilt*x` | `(2*curvature*x + tilt)*x_d` |

Run the generated and hand-written implementations together:

```bash
FORTAD_REPO=../fortad scripts/bench_itpplasma_polymorphic_select_type.sh
```

The harness allocates each child behind `class(field_model_t)`, checks fixed
expected values, then times both implementations. The dynamic type is discrete
and remains fixed within a derivative call.
