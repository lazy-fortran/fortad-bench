# Tapenade set01 `lh037`

`lh037` exercises assigned `GOTO` control flow.  The exact fixed-form source
uses deleted `ASSIGN` statements, nonstandard `REAL*8` declarations, and a
missing `DIFFSIZES.inc` include in the stored multidirectional reference.
Strict GNU Fortran therefore rejects the exact source and every stored
derivative reference.  Fresh pinned Tapenade parser, tangent, and reverse
generation succeeds, but each generated output retains the deleted assigned
`GOTO` construct and fails the same strict compiler gate.

FortAD is probed against the exact `program.f` in both forward and reverse
modes.  It refuses at line 8 (`GOTO i`), before producing a derivative file.
That is recorded as an exact feature boundary, not as support for the source.

The bounded port in `port.f90` is deliberately a straight-line specialization
of the terminating source path.  The original execution reaches the path
through labels 200, 300, 100, 300, and 400 only when `b-c > 8`; otherwise it
returns to label 200 indefinitely.  The port requires that terminating-path
precondition and replaces the assigned jumps with their resulting arithmetic:

```text
a1 = a0 + b0
b1 = b0 - c0
c1 = 2*a1*b1
a2 = a1 + 25.5
c2 = 2*a2*b1
a3 = 8*a2
```

The port is not presented as a repaired exact source.  Its JVP and VJP are
checked independently by closed-form formulas, central finite differences,
and the adjoint identity in the case-local oracle and harness.

Run from the repository root:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh037/run.sh
```

The reproducible result record is [`result.txt`](result.txt).
