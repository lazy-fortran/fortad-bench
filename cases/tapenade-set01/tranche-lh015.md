# Tapenade set01 `lh015`: strict-source refusal

`lh015` is retained as an exact upstream candidate, not as a repaired FortAD
port.  The pinned primal is not strict Fortran: its implicit `i0` is assigned
from a real expression and is then passed to `MAX` with the real expression
`i2+15`; `i3` is read before initialization; and the routine uses
`COMMON /c2/`.  Under strict GNU Fortran, the primal and stored tangent
reference fail while the stored reverse reference compiles.

Fresh parser, tangent, and reverse files from the pinned Tapenade checkout are
also generated.  The fresh parser and tangent files fail the same strict
compiler gate because their loop bound is real; the fresh reverse file
compiles.  Tapenade's own message files retain the type-mismatch, loop-bound,
and uninitialized-variable diagnostics.

FortAD `db00502` rejects the unmodified source in both forward and reverse
modes at the `COMMON` statement on line 8.  This is a reproducible exact-source
boundary, not a support claim, so no `set01_lh015` derivative port is added.

The independent harness checks a deliberately bounded observation of the
source's loop body with an explicit integer trip count and initialized values.
It has an independent primal, hand JVP/VJP, a four-step central-difference
sweep, and the JVP/VJP adjoint identity.  That observation validates the
diagnostic harness without repairing or asserting semantics for the invalid
upstream routine.

Run locally:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh015.sh
```

The reproducible record is
[`results/tapenade_set01_lh015_refusal_validation.txt`](../../results/tapenade_set01_lh015_refusal_validation.txt).
