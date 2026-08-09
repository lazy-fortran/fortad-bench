# Tapenade Fortran modern-feature queue shard: next36

Next36 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next35. They are ordered by the
fixed modern-feature score, descending score and then committed queue order:

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set06/v311` | `test` | 32 | `procedure=1; elemental=2; interface=2` | parser generated RESULT interface fails strict syntax |
| `set06/v357` | `test` | 32 | `procedure=1; elemental=2; interface=2` | parser/forward/reverse generated generic interface fails strict syntax |
| `set11/vmp09` | `test` | 32 | `procedure=1; elemental=2; interface=2` | parser generated RESULT interface fails strict syntax |
| `openmp/examples/tinymgopt` | `createandrun` | 30 | `dimension=10` | active `WRITE` at source line 51 |

The exact pinned Tapenade revision is `e59864c`; probes use FortAD revision
`a295c76`. Fresh parser, forward, and reverse probes pass for all three
generic-elemental roots and their FortAD products pass detached strict syntax
checks; detached syntax failures are recorded for the parser product of v311
and vmp09 and for all three products of v357. Their independent models check
integer/real dispatch, primal values, finite-difference JVPs, and VJP adjoint
identities, without claiming exact-source derivative support.

The OpenMP example's Tapenade parser, forward, and reverse processes return
success, but its tangent/reverse output directories contain only message files.
FortAD refuses all three modes at the active `WRITE(*,*) SUM(GRADIENT)` on line
51 before reaching the later OpenMP directive. The independent model checks the
defined six-node colored-edge primal sum and makes no derivative-support claim
for the exact I/O-containing root.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, generated-source syntax checks, revision pins,
and independent behavioral/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next36/record.py \
  --raw /var/tmp/fortad-bench-next36-set06-v311/raw.json \
  --raw /var/tmp/fortad-bench-next36-set06-v357/raw.json \
  --raw /var/tmp/fortad-bench-next36-set11-vmp09/raw.json \
  --raw /var/tmp/fortad-bench-next36-openmp-tinymgopt/raw.json
python3 cases/tapenade-queue-shard-next36/test_contract.py
```
