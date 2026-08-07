# Tapenade `todoF90/REFERENCES/v07`

`v07` is a single free-form module:

```fortran
MODULE TEST
  IMPLICIT NONE
  PRIVATE
  CHARACTER(len=*), PARAMETER :: FoX_version = '4.1.2'
  PUBLIC :: FoX_version
  PUBLIC :: OPERATOR(//)
  PUBLIC :: OPERATOR(.ADD.)
  PUBLIC :: foo
END MODULE TEST
```

The exact source is not strict Fortran: `foo` is made public but is never
declared, and the module contains no program, function, or subroutine to use
as a differentiation root.  Strict gfortran therefore stops at line 8 with
`Symbol 'foo' ... has no IMPLICIT type`.

At the pinned Tapenade revision, parser mode still emits `v07_parser_p.f90`
and `v07_parser_p.msg`; the generated parser source preserves the same
undeclared-`foo` compiler failure.  Tangent and reverse modes return status
zero but emit only messages: both report `No root unit to differentiate` and
`The code provided does not contain a top procedure`, followed by Tapenade's
undeclared-`foo` diagnostic.  There is no generated tangent or reverse source
to compile.

FortAD's exact checked-parser path reports `fortad: no function or subroutine
found in source`.  Exact forward and reverse requests using the only plausible
name, `foo`, report `fortad: no procedure named 'foo' in this source` and emit
no files.  These are source-boundary diagnostics, not derivative support
claims.

No bounded port is included.  Adding a declaration or implementation for
`foo`, or inventing operator bodies, would change the candidate instead of
testing exact support.  The independent oracle is the reproducible strict
compiler diagnostic together with the pinned source checksum.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/v07/run.sh
```

The generated evidence record is [`result.txt`](result.txt).
