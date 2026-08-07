# Tapenade `todoF90/REFERENCES/v421`: invalid explicit-shape actual boundary

The pinned source defines module `test`, with `g(z,u)` requiring a
two-element `real` array and writing `u(2)`.  `top(x,y)` calls it with the
one-element array constructor `(/y/)`.  The exact module therefore fails the
strict compiler's explicit-shape argument check before it can have a defined
runtime result; the stored association-by-address tangent has the same
problem in both its primal and differentiated calls.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds.  The
three generated files preserve the one-element constructor calls, so strict
compilation rejects each generated source at that boundary.  This separates
historical generation from the exact source's compiler validity.

FortAD's exact parser, forward, and reverse requests all refuse before writing
an output file with `unsupported expression at line 14`, the array constructor
actual in `top`.  No bounded port is included: changing the constructor to
two elements would repair the invalid source and would no longer be the v421
case.

The independent oracle does not pretend that the invalid exact call can run.
It checks the legal two-element `g` map (`z = u(1)**2`, `u(2) = z`) using a
central-difference JVP sweep and an adjoint identity, then checks that the
exact `top` actual has length one and violates the required length-two domain.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v421/run.sh
python3 cases/tapenade-set01/v421/test_contract.py
```

`result.txt` records the exact/stored compiler boundary, fresh generation and
strict compilation statuses, exact FortAD refusals, the independent oracle,
and hashes for the pinned inputs and disposable fresh outputs.
