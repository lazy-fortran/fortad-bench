# Generic selection by rank

`apply_gain` is a generic interface with scalar and rank-one procedures. The
kernel calls both overloads: the scalar call resolves to `apply_gain_scalar`,
and the array call to `apply_gain_vector`. The array is local and depends on
`x`, so
the JVP must include both the generic call and the reduction.

| Overload | Value | JVP contribution |
| --- | --- | --- |
| scalar | `2*x + 0.5` | `2*x_d` |
| rank-one (`[x, 0.25*x]`) | `3*sum(pair) + 1` | `3.75*x_d` |
| total | `5.75*x + 1.5` | `5.75*x_d` |

The harness compares generated and hand JVPs with a central finite difference.
This is the rank-selection slice of B9. Type- and kind-selection remain
separate variants in the roadmap.
