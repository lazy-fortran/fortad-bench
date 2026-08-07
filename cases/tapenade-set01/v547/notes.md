# Tapenade `todoF90/REFERENCES/v547`: legacy declaration and parser boundary

`v547` is the `endval(bb,aind,bind,cind,n)` regression from the pinned
Tapenade checkout.  Its `COMMON` state is transformed by three indexed helper
procedures: `xmul` overwrites `c0`, `xadd` overwrites `e0`, and `xdot` clears
and accumulates `a0`; the result is `a0(1)`.  The `Options` file records the
historical head specification `endval(endval)/(bb)`.

The exact primal `program.f90` compiles with strict Fortran 2018 flags.  The
stored parser and reverse references are retained as corpus evidence, but
strict compilation rejects both for legacy `REAL*8`/`INTEGER*4` declarations
and associated declaration defects.  There is no stored tangent reference.

Fresh generation from the pinned Tapenade checkout succeeds for parser,
tangent, and reverse modes using the recorded head specification.  Each fresh
source is then strictly compiled and rejected at the same legacy/declaration
boundary.  This separates generation behavior from source validity.

FortAD's exact parser, forward, and reverse requests all refuse before writing
output: the parser reports `Missing closing paren for binding label at line 62,
column 25` at the source's `INTEGER(4)` declaration.  This exact refusal is
preserved; no repaired declaration port is claimed.

`oracle.py` is independent of the compiler, Tapenade, and FortAD.  It models
the indexed overwrite/addition/accumulation pipeline on a finite domain with
repeated indices, checks a hand JVP against central differences, and checks a
hand VJP with the adjoint identity.  It does not claim that the uninitialized
or externally supplied `COMMON` state is a whole-program runtime contract.

Run the complete case probe from the worker worktree with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v547/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v547/test_contract.py
```
