# Tapenade set01 `lh035`

`lh035` is an invalid-upstream closure at the pinned Tapenade revision.  The
exact fixed-form source declares `t` as the real `COMMON /cc/ t(200)` member and
then redeclares the same symbol as `CHARACTER*10 t(3)`.  It subsequently assigns
character data to `t(15)`.  Those declarations and the assignment cannot be
interpreted as one standard-conforming Fortran object.

The only stored Fortran reference is Tapenade's `program_p.f`; `program_p.msg`
is its diagnostic record.  There is no `DIFFSIZES` include and no stored tangent
or reverse source in this upstream row.  Strict gfortran rejects both the exact
source and the stored parser reference.  Fresh pinned Tapenade parser, tangent,
and reverse generation completes, but each generated source retains the invalid
declarations and fails strict compilation.  The generated diagnostics reproduce
Tapenade's `DD02`, `DD01`, and `TC16` messages.

FortAD is probed in both forward and reverse modes against the exact source at
the pinned FortAD revision.  Both modes refuse the `COMMON` statement on line 3
and produce no derivative file.

No numeric JVP/VJP oracle is appropriate: repairing the declaration conflict or
inventing a value for the character `COMMON` state would define a different
program.  The independent closure oracle is the strict compiler's rejection of
both the exact source and the stored reference.

Run from the repository root with a clean checkout of the pinned FortAD build:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh035/run.sh
```

The reproducible record is [`result.txt`](result.txt).
