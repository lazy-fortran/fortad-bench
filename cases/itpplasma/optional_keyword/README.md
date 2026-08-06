# Optional arguments and keyword calls

`evaluate_optional` has an optional dummy and branches on `present`. The
harness calls the generated routine once with a reordered keyword argument and
once with that argument absent. This is the B8 boundary: presence is a fixed
call-site choice, while `x` is the only active input.

| Call | Value | JVP |
| --- | --- | --- |
| `evaluate_optional(coefficient=4, x=x)` | `x + 4*x` | `5*x_d` |
| `evaluate_optional(x)` | `x` | `x_d` |

The generated routine keeps `coefficient` and its tangent optional. The harness
checks both presence paths against the hand JVP and a central finite difference
oracle.
