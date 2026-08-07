# Tapenade `nonRegressions/set01/lh098`

`lh098` is the exact fixed-form upstream subroutine `ff(N,t,xbt,x)`.  It
computes a binomial-weighted sum and adds `(t+3)**(1-t)`.  `cnklog` is declared
external, so the compiler gates are compile-only and deliberately do not invent
or link a replacement implementation.

The runner pins Tapenade at `e59864cab441d4175df75383b3ff58c3dcd26df9` and
FortAD at `ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1`.  It checks the exact
source and stored forward reference with strict and legacy fixed-form compiler
flags, runs fresh pinned parser/forward/reverse generation, and strict-compiles
all fresh sources.  It then runs FortAD's exact-source `check`, JVP, and VJP
requests and strict-compiles their generated free-form sources.

No repaired Fortran port is part of this case.  `oracle.py` is independent of
Tapenade and FortAD: it evaluates the binomial formula with `lgamma`, its
analytic directional derivative, and its reverse gradient, then checks a
central-difference approximation and the adjoint identity at an interior point.

Run from the bench repository root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh098/run.sh
python3 cases/tapenade-set01/lh098/test_contract.py
```

`result.txt` is the generated evidence record.
