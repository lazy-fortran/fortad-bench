# Tapenade `nonRegressions/set05/v075`: module-only no-entry boundary

The pinned directory contains three tracked files: the exact free-form
`program.f90`, Tapenade's stored parser reference `program_p.f90`, and an
empty `program_p.msg`. The exact source is a valid `MODULE BLOCKS` with
`IMPLICIT NONE`, `PRIVATE`, and one public derived type `BLOCK`. It declares
eight scalar `integer(4)` components, `i_glob(5)`, and `j_glob(6)`. It has no
program, function, or subroutine, so there is no selected differentiation
entry point.

The stored parser reference is not a derivative and is not strict Fortran
2018: Tapenade rendered the kind declarations as `INTEGER*4`. Consequently,
the exact source compiles under the requested strict flags, while the stored
reference and a fresh Tapenade parser source refuse at the extension with
`-pedantic-errors`. Fresh tangent and reverse runs produce only message files
reporting `No root unit to differentiate` and no generated source.

FortAD is asked to check, forward-transform, and reverse-transform the exact
source without a fabricated procedure name. Each request reaches the same
principled boundary: `fortad: no function or subroutine found in source`,
with no output file. There is no bounded port because introducing a callable
wrapper or derivative interface would add semantics absent from the corpus.

`oracle.py` is independent of gfortran, Tapenade, and FortAD. It parses the
exact declaration text and constructs a deterministic numerical layout model:
the 19 declared integer components are assigned values 1..8, 101..105, and
201..206 in Fortran declaration order, giving a weighted layout checksum of
26043. This checks the only semantics present in the source without claiming
a numerical function or derivative.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v075/run.sh
python3 cases/tapenade-set01/v075/test_contract.py
```

Compiler modules, generated files, logs, and FortAD outputs are disposable
under `/var/tmp`; only this case directory is committed.
