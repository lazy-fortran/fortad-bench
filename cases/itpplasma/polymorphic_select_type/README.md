# Runtime-selected field JVP and VJP

This case follows the structure used by KAMEL's KIM factory and rabe's field
hierarchy: an abstract base reaches one of two concrete field models at runtime.
The active kernel selects the dynamic type.

For direction `x_d` and output cotangent `y_b`, the hand derivatives are:

| Child | Primal | JVP | VJP `x_b` |
|---|---|---|---|
| `linear_field_t` | `scale*x + offset` | `scale*x_d` | `scale*y_b` |
| `quadratic_field_t` | `curvature*x*x + tilt*x` | `(2*curvature*x + tilt)*x_d` | `(2*curvature*x + tilt)*y_b` |

Run the generated and hand-written implementations together:

```bash
FORTAD_REPO=../fortad scripts/bench_itpplasma_polymorphic_select_type.sh
```

The harness checks generated and hand derivatives for each child, compares the
VJP with a central finite difference, and verifies
`y_b*JVP(x_d) = x_d*VJP(y_b)`. It then times the generated and hand JVP and VJP
paths separately.

The dynamic type is discrete and remains fixed within a derivative call.
Changing from one child type to another is outside the derivative contract.
