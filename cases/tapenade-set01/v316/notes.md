# Tapenade `nonRegressions/set06/v316`: invalid module with no entry point

The exact free-form source is only `MODULE M`.  It declares four real pointer
objects and no program, subroutine, or function.  The declarations are not a
callable interface: strict Fortran 2018 compilation rejects `p2 = null()`,
`p3 => p1` because `p1` lacks `TARGET`, and `p4 = p1`.  The stored Tapenade
parser reference has the same three compiler refusals, while its stored message
records Tapenade's `TC16` type-mismatch diagnostic.

Fresh pinned Tapenade parser generation succeeds as a parser probe and emits
`v316_p.f90` plus `v316_p.msg`; the generated parser file has the same strict
compiler boundary.  Fresh tangent and reverse generation exits successfully
but emits message-only `v316_d.msg` and `v316_b.msg`, each reporting that there
is no root unit and no top procedure, followed by the source's `TC16` message.

FortAD is probed with the exact module name as the requested procedure.  Its
parser/check, forward, and reverse requests all reproducibly exit with
`fortad: no procedure named 'm' in this source` and write no output.  This is
the expected no-callable-entry refusal; no FortAD derivative request can be
meaningfully selected for this source.

The independent Python oracle inventories the source text itself: one module,
four named pointer declarations, the three invalid initializer patterns, and
zero callable or executable units.  Because there is no callable interface or
observable result, a numerical oracle or synthetic derivative port would
invent semantics and is intentionally absent.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v316/run.sh
python3 cases/tapenade-set01/v316/test_contract.py
```

The generated compiler, Tapenade, FortAD, diagnostic, and checksum record is
in [`result.txt`](result.txt).
