# Tapenade `todoF90/REFERENCES/v05`

`v05` is one free-form source containing the external function `RETARD` and
the subroutine `COMP_PRECIPITATION`.  The latter calls `RETARD(CK(1,1),...)`,
although `RETARD` declares scalar `CK`; the external call also has no explicit
interface while `RETARD` declares optional dummies.  Strict and legacy
gfortran both reject the exact source with a return-type mismatch at that
call.  There is no stored parser, tangent, reverse, or message reference in
the pinned directory.

Fresh pinned Tapenade generation succeeds in all six requested probes.  For
`RETARD`, parser generation produces `v05_p.f90`, which strict compilation
rejects because the optional-argument function requires an explicit
interface; tangent and reverse generation produce strictly compilable
sources.  For `COMP_PRECIPITATION`, parser generation produces the same
non-compiling parser source, while tangent and reverse produce only `.msg`
files reporting that the root has no active input or output.  These are fresh
engine artifacts, not evidence that the original source is valid.

FortAD's parser check for `RETARD` writes non-compiling output with blank
identifiers, while its parser check for `COMP_PRECIPITATION` refuses the
invalid `RETARD` call.  The forward `RETARD` probe likewise writes
non-compiling output; forward and reverse `COMP_PRECIPITATION` probes refuse
the call, and reverse `RETARD` refuses the undeclared function-result
assignment.  The runner records these exact boundaries and does not create a
port: changing the interface or changing `CK(1,1)` into a scalar would test a
different program.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/v05/run.sh
```

The reproducible compiler, fresh-generation, FortAD, and checksum record is
in [`result.txt`](result.txt).
