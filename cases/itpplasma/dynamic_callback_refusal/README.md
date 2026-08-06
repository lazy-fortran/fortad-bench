# Dynamic callback refusal

`evaluate_dynamic` calls the module procedure pointer `selected_callback`.
The primal program assigns both callback targets and checks their values, so
the input is valid executable Fortran.

FortAD cannot yet follow a runtime procedure target. At commit `1e5694c`, the
forward transform exits nonzero, writes no derivative file, and names the
call:

```text
fortad: no derivative rule for 'selected_callback'; register one with fad_add_rule, or keep it out of the active path
```

That refusal prevents an incorrect zero tangent. The adjacent
[`SELECT TYPE` case](../callback_select_type/README.md) expresses the same two
formulas in the supported form. Run both checks with:

```sh
FORTAD_REPO=../fortad scripts/bench_itpplasma_callback_boundary.sh
```
