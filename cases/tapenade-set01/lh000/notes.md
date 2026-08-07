# Tapenade `nonRegressions/set01/lh000`

`lh000` is a no-entry-point row at the pinned Tapenade commit.  Both tracked
source files, `program.f` and `program.f90`, are exactly empty.  The six
tracked references are message files rather than Fortran derivative sources:
`program_p.msg` is empty, while the tangent/reverse variants report:

```text
1 Command: No root unit to differentiate
2 File: The code provided does not contain a top procedure
```

The source/reference inventory therefore contains no program, function, or
subroutine to transform.  This is not a missed transformable procedure and
not a standalone program: it is an empty derivative/reference-only corpus
row.  No independent/dependent variables or entry point can be selected
without inventing semantics.

The runner checks both empty sources with the requested strict free-form
Fortran flags, runs fresh pinned Tapenade parser, tangent, and reverse probes,
and checks that the generated messages preserve the stored no-entry boundary.
The parser probe emits an empty `lh000_p.msg`; tangent and reverse emit the
two-line no-root message and no Fortran source.  FortAD parser/forward/reverse
requests are recorded as not applicable rather than made against a guessed
procedure name.

There is no bounded port and no numerical derivative oracle: an empty source
has no callable semantics or interface to preserve.  `oracle.py` is an
independent semantic oracle for the exact empty-source shape and refusal
messages.  It deliberately does not call a compiler, Tapenade, or FortAD.

Run from the worker repository root with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh000/run.sh
python3 cases/tapenade-set01/lh000/test_contract.py
```

The reproducible gate record is [`result.txt`](result.txt).
