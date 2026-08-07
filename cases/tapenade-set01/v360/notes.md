# Tapenade `nonRegressions/set06/v360`: module-only no-entry boundary

The exact free-form row contains two modules and no `PROGRAM`, `SUBROUTINE`,
or `FUNCTION`. `M0` declares `m0_i = 2`; `M1` uses `M0` and declares the
private `gm_levels`, `gm_show`, and `gm_unit` module objects. The stored
Tapenade reference is `program_p.f90`; `program_p.msg` exists and is empty.
There are no stored tangent or reverse source/message references.

Both exact files pass the pinned strict Fortran 2018 compiler gate. With
`-Wall -Wextra`, each produces only the expected unused-private-module-variable
warnings for `gm_show` and `gm_unit`. The stored reference adds `IMPLICIT NONE`
and `SAVE` attributes but remains a declaration-only module pair.

Fresh pinned Tapenade parser generation emits `v360_p.f90` and an empty
`v360_p.msg`; the fresh parser source also passes the strict compiler gate.
Fresh tangent and reverse generation exits successfully but emits only
`v360_d.msg` and `v360_b.msg`, each containing `No root unit to differentiate`
and `The code provided does not contain a top procedure`. Neither mode emits a
derivative source file.

The repaired FortAD CLI at commit `3a946d34d3caa7a75fb6f891139023650b4ce51a`
is probed with the exact module name `m0` as the requested procedure. Its
parser/check, forward, and reverse requests each exit nonzero, write no output,
leave stdout empty, and report only `fortad: no procedure named 'm0' in this
source` on stderr. This does not turn a module into an entry point.

The independent Python oracle inventories the source text itself: the two
modules, their `M1 USE M0` dependency, all expected declaration forms and
values, and zero callable or executable units. No synthetic root, bounded
port, harness, or numerical derivative claim is made because the source has no
callable interface.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v360/run.sh
python3 cases/tapenade-set01/v360/test_contract.py
```

Only this case directory is intended to be committed.
