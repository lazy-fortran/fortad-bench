# Tapenade `todoF90/REFERENCES/v101`: allocated local-array boundary

The exact free-form routine `head(x,y)` allocates a local `a(2)`, fills it
from the two elements of `x`, tests `ALLOCATED(a)`, computes `y(1)`, and then
deallocates `a`.  The pinned directory also contains association-by-address
reverse and forward references and the `Options` line
`-association byaddress -vars x -outvars y`.

The exact primal and both stored references compile with the strict F2018
gate.  Fresh pinned Tapenade parser, tangent, and reverse generation with the
recorded association-by-address options produces all three sources, and all
three fresh sources compile strictly.  This establishes the reference
behavior without treating the stored derivatives as a fresh run.

FortAD's exact parser, forward, and reverse requests all refuse at the
allocatable declaration on line 6 with the same allocation-lifetime
diagnostic.  They emit no derivative source.  This is an exact-source
capability boundary, not an upstream compiler failure.

The bounded `port.f90` retains the arithmetic and specializes the always-
allocated normal path to a fixed `a(2)`.  Its independent formula is
`y(1)=4*x(1)*x(2)`, with JVP
`y_d(1)=4*(x_d(1)*x(2)+x(1)*x_d(2))` and VJP
`x_b=(4*x(2)*y_b(1),4*x(1)*y_b(1))`.  The Python oracle checks these formulas
against a central-difference sweep and the adjoint identity; the Fortran
harness checks the generated FortAD forward and reverse routines against the
same hand implementation.  The port does not claim allocation failure,
unallocated-state, or general allocatable-lifetime support.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v101/run.sh
python3 cases/tapenade-set01/v101/test_contract.py
```

The generated compiler, Tapenade, FortAD, bounded-harness, and checksum
record is in [`result.txt`](result.txt).
