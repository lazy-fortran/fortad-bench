# Tapenade `nonRegressions/set07/v544`: module-only no-entry boundary

The exact v544 directory contains one free-form module, `TEST`.  It defines
the `C_INTPTR_T` parameter, the private `C_PTR` type and its `ptr` component,
and the `C_NULL_PTR` parameter.  There is no `PROGRAM`, `SUBROUTINE`, or
`FUNCTION` unit.  The stored Tapenade reference is `program_p.f90` and its
`program_p.msg` is empty; no stored tangent or reverse references exist.

The exact source and stored parser reference compile with strict Fortran 2018
flags.  Fresh pinned Tapenade parser generation emits `v544_p.f90` and an
empty `v544_p.msg`; the generated parser source also compiles strictly.  Fresh
tangent and reverse generation exits successfully but emits only `v544_d.msg`
and `v544_b.msg`, each reporting `No root unit to differentiate` and that the
code contains no top procedure.  Neither mode emits a derivative source.

FortAD 3a946d3 is probed against the exact source without `--proc`.  Its
parser, forward, and reverse requests all exit nonzero with `no function or
subroutine found in source` and write no output.  This records the module-only
boundary; no module is treated as a synthetic root and no derivative port is
claimed.

`oracle.py` independently inventories the source text itself.  It requires
the exact module, type, parameter, private component, and initializer
semantics, and requires zero callable or executable units.  It does not invoke
gfortran, Tapenade, or FortAD.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v544/run.sh
python3 cases/tapenade-set01/v544/test_contract.py
```

Generated files, compiler modules, FortAD output, and logs remain disposable
under `/var/tmp`.  Only this case directory is intended to be committed.
