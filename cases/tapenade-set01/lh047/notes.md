# Tapenade `nonRegressions/set01/lh047`

`lh047` is a fixed-form `adj13bis`/`sub1` regression. The exact procedure
stores `x` and `y` in `COMMON /cc/`, passes scalar `x(i)` to the explicit-shape
array dummy `y2`, and uses `v` before its first assignment. The exact source,
stored tangent/reverse references, and fresh pinned Tapenade parser/tangent/
reverse outputs all pass the strict compiler gate.

FortAD refuses both exact modes at `COMMON /cc/`, line 5. The bounded port
projects the only accessed state slots (`x(1)`, `x(8:11)`) to explicit
arguments and makes the initial `v` an explicit input. Its JVP compiles and
passes hand, central-difference, and adjoint-identity checks. Reverse output
is generated but strict compilation refuses assignments to the dependent seed
`t_b` declared `INTENT(IN)`. No exact-source support claim is made.
