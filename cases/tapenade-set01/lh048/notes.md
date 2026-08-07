# Tapenade `nonRegressions/set01/lh048`

This fixed-form case has entry point `adj13bis(u,z,t)`. It stores `x` and `y`
in COMMON `/cc/`, calls `sub1` twice with `x(i)` as the actual argument for an
array dummy `y2(0:6)`, and reads the incoming `v` before assigning it. The
exact and stored primal/tangent/reverse references all pass the strict compiler
oracle, as do fresh pinned Tapenade parser, tangent, and reverse outputs.

FortAD refuses both exact probes at the COMMON declaration on line 5. The
bounded port is explicit about the state and makes the otherwise undefined
incoming `v` an argument; it preserves the legacy storage offsets
`y2(3) -> x(i+3)` and `y2(5) -> x(i+5)`. Its forward transform compiles and
passes an independent hand evaluation, central-difference sweep, and adjoint
identity. FortAD reverse generation is recorded, but its generated interface
contains duplicate `t_b` formals and therefore fails strict compilation.

Run reproducibly with:

```text
FORTAD_REPO=/path/to/fortad \
TAPENADE_REPO=/path/to/tapenade \
  cases/tapenade-set01/lh048/run.sh
python3 cases/tapenade-set01/lh048/test_contract.py
```
