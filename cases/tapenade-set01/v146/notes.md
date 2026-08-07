# Tapenade `nonRegressions/set05/v146`: no-entry/reference-only boundary

The pinned v146 directory contains three tracked files: `program.f90`, the
stored parser output `program_p.f90`, and its message file.  Both Fortran files
define only module `A`; neither contains a `PROGRAM`, `SUBROUTINE`, or
`FUNCTION`.  The module has no `CONTAINS` section and therefore no procedure
that the extractor could have missed.  It is not a standalone program.

The exact source and stored parser reference are also not strict-conforming:
`wp=2` is not a supported real kind for this compiler, and `1.d-7_wp` combines
a `D` exponent with an explicit kind.  Fresh pinned Tapenade parser generation
re-emits the same module and diagnostic, while tangent and reverse probes with
the module name as a would-be root create only message files saying that `A` is
not a standard procedure and that there is no root unit.

There is no selected entry point, so no FortAD derivative request is claimed.
The runner probes the same module name in parser, forward, and reverse forms
only to record the principled no-procedure boundary; each request emits no
file.  `oracle.py` independently inventories the module structure and the two
invalid semantic forms.  It does not repair the module, assign a derivative, or
claim a bounded port.

Run the complete evidence with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v146/run.sh
python3 cases/tapenade-set01/v146/test_contract.py
```

Generated Tapenade files, compiler objects, FortAD output, and logs stay in a
disposable temporary directory.  Only this case directory is part of the
commit.
