# Tapenade `nonRegressions/set06/v317`: module-only no-entry boundary

The pinned directory contains the exact free-form source, Tapenade's stored
parser rendering, and an empty stored parser message.  `program.f90` defines
only `MODULE M`, with one module pointer declaration `p1 => NULL()`.  There is
no `program`, `subroutine`, `function`, or executable unit, so there is no
callable entry point or derivative contract.

The exact source and stored parser reference both pass the strict Fortran 2018
compiler gate.  Fresh pinned Tapenade parser generation emits `v317_p.f90` and
an empty `v317_p.msg`; the generated parser source also passes the strict
compiler gate.  Fresh tangent and reverse generation exit successfully but
emit only `v317_d.msg` and `v317_b.msg`, each recording `No root unit to
differentiate` and `The code provided does not contain a top procedure`.

FortAD at the repaired `3a946d3` revision is probed against the exact source
with parser, forward, and reverse requests naming `m`.  Each request refuses
with `fortad: no procedure named 'm' in this source` and emits no output.  The
module name is used only to exercise the no-entry diagnostic; it is not treated
as a procedure, and no synthetic root or derivative port is added.

`oracle.py` independently inventories the source text: one module, one
null-initialized pointer, and zero callable or executable units.  Since the
source has no callable interface or observable result, a numerical oracle or
bounded derivative port would invent semantics and is intentionally absent.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v317/run.sh
python3 cases/tapenade-set01/v317/test_contract.py
```

The generated compiler, Tapenade, FortAD, diagnostic, and checksum record is
in [`result.txt`](result.txt).  All generated artifacts are disposable; only
this case directory is committed.
