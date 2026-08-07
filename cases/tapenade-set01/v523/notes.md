# Tapenade `nonRegressions/set07/v523`: empty no-entry boundary

The pinned v523 directory contains exactly two zero-byte artifacts: the
free-form `program.f90` source and the stored `program_p.msg` parser message.
There is no stored generated Fortran source.  Strict Fortran 2018 compilation
accepts the empty `program.f90` without diagnostics; the `.msg` file is empty
Tapenade metadata and has no stored-reference source compilation claim.

Fresh pinned Tapenade parser, tangent, and reverse invocations all exit
successfully without a root.  Parser mode creates only an empty `v523_p.msg`.
Tangent and reverse modes create only `v523_d.msg` and `v523_b.msg`, each
reporting `No root unit to differentiate` and that the code contains no top
procedure.  No generated Fortran source exists in any mode.

The repaired FortAD 3a946d3 CLI is probed against the exact empty source in
parser, forward, and reverse modes.  Each request refuses quietly with
`no function or subroutine found in source`, returns nonzero, and writes no
output file.  The option names used for forward and reverse are CLI probes;
they do not assert source variables or create a synthetic procedure.

`oracle.py` is independent of gfortran, Tapenade, and FortAD.  It inventories
the source text itself and requires zero modules, zero programs, zero callable
procedures, and zero executable statements.  The resulting derivative domain
is empty, so no procedure, root, repaired source, or derivative port is
invented.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v523/run.sh
python3 cases/tapenade-set01/v523/test_contract.py
```

Generated files and compiler modules remain disposable under `/var/tmp`.
The compiler, fresh Tapenade, FortAD, independent-oracle, and input checksum
record is in [`result.txt`](result.txt).
