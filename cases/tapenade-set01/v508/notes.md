# Tapenade `todoF90/REFERENCES/v508`: external inout and global-state boundary

`v508` contains a small free-form module plus three external procedures.
`compute(x,y)` overwrites `y` with `2*x`, returns `y(1)*y(2)`, and adds that
value to module variable `global`.  `ftest` passes the external `compute` to
`top`, so the exact top-level observable is the scalar
`top = 4*r(1)*r(2)`, with the in-place state `s = 2*r` and the side effect
`global <- global + top`.

The exact primal and stored forward reference compile with strict free-form
flags.  Fresh generation from the pinned Tapenade checkout succeeds in parser,
tangent, and reverse modes when the exact `Options` heads (`top` and
`compute`) are supplied.  Fresh parser and tangent sources compile strictly;
the fresh reverse source fails strict compilation because Tapenade emits an
undeclared `COMPUTE_B` interface.

FortAD's exact parser and forward requests return files, but those files are
not valid Fortran: the parser contains `result()` and blank declarations, and
the forward subroutine has blank dependent arguments.  Strict compilation
rejects both.  Exact reverse generation refuses at the assignment to the
undeclared temporary `y` and writes no file.  These are preserved as exact
code-generation/refusal boundaries.

`oracle.py` is independent of the Fortran compiler, Tapenade, and FortAD.  It
models the closed-form top map and the two defined state effects, checks the
hand JVP against central differences, and checks the hand VJP with an adjoint
identity.  No bounded port is included: changing the external inout call or
making the module global an explicit argument would define a different
candidate.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v508/run.sh
python3 cases/tapenade-set01/v508/test_contract.py
```

`result.txt` records exact/reference compilation, fresh generation and strict
compilation, FortAD's three exact-mode boundaries, the independent oracle, and
all pinned input hashes.  Generated files and build products stay in a
disposable `/var/tmp` directory.
