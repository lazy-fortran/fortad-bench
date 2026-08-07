# Tapenade `todoF90/REFERENCES/v270`

The pinned candidate is module `SIMTEST1`.  Its public procedure is
`SOLVEREAL(this,c)`, which updates the allocatable `this%cmob` component by
calling the private `qCalc` function.  The source uses legacy `REAL*8` and
`INTEGER*4` declarations throughout the derived type and procedure.

Strict free-form Fortran 2018 compilation rejects the upstream source at the
first `REAL*8` declaration.  The stored `program_d.f90` and `program_dv.f90`
references fail at the same strict boundary; their later missing size
parameters and invalid specification expressions are therefore recorded as
secondary defects, not repaired here.

Fresh pinned Tapenade parser, tangent, and reverse generation all return
success and emit sources, but each fresh source fails the same strict compiler
gate.  `NoInlineABS` is resolved relative to Tapenade's `todoF90` working
directory.  FortAD's exact parser, forward, and reverse modes all refuse the
source before emitting output because allocatable derived-type component
allocation lifetime is not represented.

This case deliberately has no bounded port.  Replacing the legacy kinds,
exposing allocated state, or selecting one of the twenty-four isotherm
branches would no longer be the pinned candidate.  The independent oracle is
the reproducible strict diagnostic plus the pinned source checksum contract;
there is no numerical oracle for a source that fails the exact strict
compilation gate.

Run the complete case with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v270/run.sh
python3 cases/tapenade-set01/v270/test_contract.py
```
