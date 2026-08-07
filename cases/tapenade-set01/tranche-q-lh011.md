# Tapenade set01 `lh011`: exact-source refusal

The exact fixed-form source declares a local `integer i` but never assigns it
before the computed `GOTO` at line 6.  It then conditionally calls `TOTO` and
`TUTU` with alternate returns, although neither routine nor any differentiated
variant is present in the candidate directory.  GNU Fortran accepts the
primal as an object with obsolescence and uninitialized-use warnings, but there
is no bounded, linkable execution contract to port without changing the
source's behavior.

At the pinned Tapenade revision, fresh parser and forward files compile under
strict Fortran flags.  The fresh reverse file, like the stored reverse
reference, is rejected by the same strict gate because Tapenade emits
`INTEGER*4 branch` and then uses `branch` without a declaration after that
extension is rejected.  This is recorded as evidence, not support.

FortAD at baseline `db00502` refuses the unmodified source in both forward and
reverse modes with the stable diagnostic `fortad: unsupported statement at
line 6` for the computed `GOTO`.  No repaired FortAD port is included.

The committed oracle models only the defined control-flow slice for explicit
selectors `0, 1, 2, 3, 10`, before the unresolved external calls.  It checks
the branch assignments, an independent hand JVP/VJP, a four-step central
difference sweep, and the adjoint identity.  It intentionally does not claim
that the original uninitialized/external-call routine is executable.

Run the reproducible record with the pinned checkouts:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh011.sh
```

The generated report is
[`results/tapenade_set01_lh011_refusal_validation.txt`](../../results/tapenade_set01_lh011_refusal_validation.txt).
