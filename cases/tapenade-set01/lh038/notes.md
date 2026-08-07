# Tapenade `nonRegressions/set01/lh038`

This case exercises a fixed-form `top(x)` entry point whose `pi` value is held
in COMMON `/ext/`. `top` calls `test`, and the active branch in `test` calls
`F1`, which reads the same COMMON value. The exact source and every stored
Fortran reference compile with the pinned strict fixed-form compiler oracle.

Fresh pinned Tapenade parser, forward, and reverse generation all succeed and
each fresh generated file compiles strictly. The stored multidirectional
reference also compiles with the pinned `DIFFSIZES.f` include.

FortAD's exact forward and reverse probes refuse at line 3, the COMMON
declaration. The bounded port makes COMMON state explicit as `pi`; it keeps
the conditional call structure and is therefore not presented as exact source
support. FortAD forward generation compiles and passes the independent hand,
finite-difference, and adjoint checks. FortAD reverse generation returns a
file but strict compilation refuses the duplicate `x_b` dummy in its generated
interface, so this case does not claim bounded reverse support.

The bounded entry point is `set01_lh038(pi,x)`, with independent inputs `pi`
and `x` and dependent output `x`. Away from the branch boundary its closed
form is `x` for `x <= 20`, and `11.3 + pi` for `x > 20`. The runner records
the exact commands, pinned revisions, diagnostics, source/generated hashes,
and numerical oracle output.

Run reproducibly with:

```text
FORTAD_REPO=/path/to/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh038/run.sh
python3 cases/tapenade-set01/lh038/test_contract.py
```
