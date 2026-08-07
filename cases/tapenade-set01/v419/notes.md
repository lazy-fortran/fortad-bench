# Tapenade `todoF90/REFERENCES/v419`: context-association boundary

`v419` is a free-form program with modules `MMA` and `MMB`, allocatable module
state, a COMMON block, and the subroutine `ROOT(X)`.  Its historical options
request context association by address.  The source allocates `X(30)` but
initializes only elements 1 through 20, allocates `TT1` and `TT2` without
initializing the elements later read by `ROOT`, and applies `SUM(X)` to the
assumed-size dummy `X(*)`.  Strict F2018 compilation therefore refuses the
exact primal at the assumed-size intrinsic reference.

The stored `program_Rd.f90` is preserved as an expected strict-compilation
refusal.  It contains malformed `%v` references on ordinary `x` and `v`
variables, missing `ISIZE1OF...` declarations, and an incompatible
`INITSOME_RD` call.  The shared pinned `nonRegressions/DIFFSIZES.f90` module is
compiled only as the historical generated-code support dependency.

Fresh pinned Tapenade parser, tangent, and reverse runs all generate files.
Strict compilation rejects the parser at `SUM(x)`, the tangent at missing
context-size declarations and `SUM(xd)`, and the reverse at `INTEGER*4`, missing
context-size declarations, and `SUM(x)`.  These are recorded separately from
the successful generation status.

FortAD is probed on the exact source in all three modes.  Each mode refuses
before writing output at line 5, the first allocatable declaration/component
in module `MMA`.  No bounded port is included: initializing the allocated
arrays, changing `X` to an explicit-shape dummy, or replacing the allocation
and COMMON context would define a different program.

`oracle.py` is independent of the compiler, Tapenade, and FortAD.  It computes
the independently known initialized prefixes (`AA(1:20)` and `X(1:20)`) and
checks the remaining undefined reads and the standard-invalid `SUM(X(*))`
boundary.  It intentionally makes no derivative claim for an undefined map.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v419/run.sh
python3 cases/tapenade-set01/v419/test_contract.py
```

The compiler, fresh-generation, FortAD, semantic-oracle, and checksum record
is in [`result.txt`](result.txt).
