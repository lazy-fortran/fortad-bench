# Tapenade `nonRegressions/set05/v147`: no-entry/reference-only boundary

The pinned v147 directory contains the exact source `program.f90`, the stored
parser reference `program_p.f90`, and its empty message file.  Both Fortran
files define only module `A`; neither contains a `PROGRAM`, `SUBROUTINE`, or
`FUNCTION`.  The module has no `CONTAINS` section.  Its logical and derived-type
pointer declarations are data declarations, not callable entry points, so the
directory is not a standalone program.

Strict gfortran accepts both exact files with the repository's strict free-form
flags.  Fresh pinned Tapenade parser generation emits `v147_p.f90` and
`v147_p.msg`, with the message that `A` is not a standard procedure.  Tangent
and reverse probes with the module name as a would-be root emit only `v147_d.msg`
and `v147_b.msg`; both report that there is no root unit to differentiate and
that the code has no top procedure.

There is no selected entry point, so no FortAD derivative request is claimed.
The runner probes the same module name in parser, forward, and reverse forms
only to record the principled no-procedure boundary; each FortAD request
refuses with `no procedure named 'A' in this source` and emits no output.
`oracle.py` independently inventories the module structure and data-only
declarations.  It does not repair the module, assign a derivative, or claim a
bounded port.

Run the complete evidence with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v147/run.sh
python3 cases/tapenade-set01/v147/test_contract.py
```

Generated Tapenade files, compiler objects, FortAD output, and logs stay in a
disposable temporary directory.  Only this case directory is part of the
commit.
