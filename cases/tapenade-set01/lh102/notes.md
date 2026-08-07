# Tapenade `nonRegressions/set01/lh102`

`lh102` is the queued fixed-form procedure candidate whose exact upstream
entry point is `TESTPROTECT(xx,yy,zz,vv1,vv2,vv3)` in `program.f`.  The
adjacent `program_b.f` and `program_d.f` are the stored Tapenade reverse and
forward references.  The source protects power, square-root, and logarithm
operations with tests intended to avoid invalid derivative evaluations.

This package preserves the upstream source by reference.  It does not copy,
edit, or silently repair any Fortran source.  The runner checks the exact
upstream SHA-256 values and generates fresh pinned Tapenade parser, forward,
and reverse outputs in a temporary directory.

The exact upstream files and all fresh Tapenade files pass the fixed-form
strict and legacy syntax-only compiler gates.  FortAD at the requested commit
accepts an exact `check` request and emits free-form checked source.  Its exact
JVP request also returns success and emits a module, but the emitted routine
contains only the `zz` update and references an unassigned `tmpY`; it does not
represent the complete `TESTPROTECT` computation.  Exact VJP requests require
one dependent at a time, so the runner records the `yy` request.  That output
is syntactically accepted but contains no reverse propagation for this
procedure and initializes all requested adjoints to zero.  These are observed
FortAD results, not a repaired port or a claim of derivative correctness.

`oracle.py` independently models the primal procedure's branch and valid
positive-base power behavior in Python.  `test_contract.py` has exactly three
behavioral tests: the inactive branch, a positive primal evaluation, and a
finite-difference directional check of the two computed outputs.  The oracle
does not call Tapenade or FortAD.

Run from the benchmark repository root with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh102/run.sh
python3 cases/tapenade-set01/lh102/test_contract.py
```

The reproducible gate record is [`result.txt`](result.txt).
