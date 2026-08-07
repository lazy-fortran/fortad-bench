# Tapenade `nonRegressions/set11/vpf16`: module-only/no-entry boundary

The exact free-form source contains two modules and no `PROGRAM`, `SUBROUTINE`,
or `FUNCTION`. `ESMF_CalendarMod` declares the logical component-bearing type
`ESMF_Calendar`, its default `.false.` component value, and the integer
`ESMF_Calendar_dummy`. Module `mo` uses those two names and marks both imported
entities private. The checked-in `Options` file contains
`-msginfile -noinclude -noisize`.

The exact source and stored `program_p.f90` compile as strict Fortran 2018
modules. Fresh pinned Tapenade parser mode emits `vpf16_p.f90` and an empty
`vpf16_p.msg`; tangent and reverse mode emit only `vpf16_d.msg` and
`vpf16_b.msg`, each reporting `No root unit to differentiate` and that the
code does not contain a top procedure. The runner invokes Tapenade from the
source directory so the checked-in Options metadata is part of the probe.

FortAD parser mode refuses the exact source with `no function or subroutine
found in source`. Forward and reverse requests naming `esmf_calendarmod` as a
putative procedure refuse with `no procedure named 'esmf_calendarmod' in this
source`. No output is written in any mode.

The independent oracle inventories the two modules, the `mo USE
ESMF_CalendarMod, ONLY: ...` dependency, the declarations, and zero callable
or executable units. There is no synthetic root, wrapper, derivative port, or
numerical runtime claim because this source has no callable interface.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/vpf16/run.sh
python3 cases/tapenade-set01/vpf16/test_contract.py
```

Generated files and compiler modules remain disposable under `/var/tmp`.
