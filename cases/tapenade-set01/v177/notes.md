# Tapenade `nonRegressions/set05/v177`: module-only no-entry boundary

The pinned v177 directory contains exactly three tracked files.  The primal
`program.f90` is a free-form `module mcrm2par` unit containing parameters,
arrays, and two scalar module variables.  It contains no `PROGRAM`,
`FUNCTION`, or `SUBROUTINE`.  `program_p.f90` is the stored Tapenade parser
copy of that module and `program_p.msg` is empty.  There are no stored tangent
or reverse files or messages.

Strict F2018 compilation of the exact primal records both nonconforming tab
characters and the legacy `INTEGER*4`/`REAL*8` declarations.  The stored
parser reference is also rejected for its nonstandard type declarations.
These are compiler-boundary observations, not derivative results.

Fresh pinned Tapenade parser generation succeeds and emits
`v177_p_p.f90`/`v177_p_p.msg`; the generated parser source has the same strict
nonstandard-type refusal.  Fresh tangent and reverse generation succeeds as a
command but emits only `v177_d_d.msg` and `v177_b_b.msg`, each reporting that
there is no root unit to differentiate and no top procedure.

FortAD is probed against the exact source without a guessed procedure name.
Its parser check and forward/reverse requests all return status 1 with
`fortad: no function or subroutine found in source` and write no output.
Because the corpus has no callable entry point, no synthetic root, bounded
port, or numerical derivative oracle is included.  `oracle.py` independently
models the module's constants, ranks, and storage element counts while
checking that the stored parser copy preserves that module-only semantics.

Run the complete evidence probe from the worker checkout:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v177/run.sh
python3 cases/tapenade-set01/v177/test_contract.py
```

Generated sources, compiler modules, logs, and FortAD outputs are disposable
under `/var/tmp`; only this case directory is committed.
