# Tapenade `nonRegressions/set05/v201`: module-only no-entry boundary

The pinned directory contains exactly three tracked files: the exact
`program.f90`, Tapenade's stored parser output `program_p.f90`, and an empty
`program_p.msg`.  The exact source is `MODULE TEST` with `IMPLICIT NONE`, two
integer parameters, and three module-level real arrays.  It has no `PROGRAM`,
`SUBROUTINE`, `FUNCTION`, or `CONTAINS`, so there is no callable procedure or
selected differentiation entry point.

The exact source is rejected by the repository's strict free-form compiler
flags because the historical file contains tab characters and legacy
`INTEGER*4`/`REAL*8` declarations.  The stored parser reference and the fresh
pinned parser output are rejected for their legacy `INTEGER*4`/`REAL*8`
declarations.  These are source/reference validity boundaries, not repaired
inputs.

Fresh pinned Tapenade parser generation emits `v201_p.f90` and an empty
`v201_p.msg`.  Fresh tangent and reverse generation emit no Fortran source;
their message files contain exactly:

```text
1 Command: No root unit to differentiate
2 File: The code provided does not contain a top procedure
```

FortAD is probed against the exact source in parser, forward, and reverse
forms without naming a fabricated procedure.  Each request exits with
`fortad: no function or subroutine found in source` and writes no output.
There is no bounded port or derivative runtime claim because the corpus row
has no callable interface.

`oracle.py` is independent of gfortran, Tapenade, and FortAD.  It inventories
the module declarations, computes the three Fortran array extents from the
two parameters, and checks the resulting total storage/layout checksum.  It
does not turn module state into a synthetic procedure.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v201/run.sh
python3 cases/tapenade-set01/v201/test_contract.py
```

Generated files, compiler modules, FortAD output, and logs remain disposable
under `/var/tmp`; only this case directory is committed.
