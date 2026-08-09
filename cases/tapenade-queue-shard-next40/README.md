# Tapenade Fortran modern-feature queue shard: next40

Next40 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form procedure candidates after next39. Selection uses the fixed
case-insensitive modern-feature score, descending score, then committed queue
order for ties.

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set05/v098` | `sub1` | 17 | `type(=1; dimension=3` | legacy derived-type declaration at line 1 |
| `set05/v099` | `sub1` | 17 | `type(=1; dimension=3` | legacy derived-type declaration at line 1 |
| `set05/v100` | `sub1` | 17 | `type(=1; dimension=3` | legacy derived-type declaration at line 1 |
| `set06/v263` | `test` | 17 | `allocatable=1; dimension=1` | reverse dependent inference among multiple outputs |

The exact pinned Tapenade revision is `e59864c`; probes use FortAD revision
`98201ce`. Tapenade parser, forward, and reverse products pass for all four
roots. FortAD explicitly refuses all three modes for the three legacy
derived-type component-section cases. For `v263`, FortAD parser and forward
products pass, while reverse refuses because no single dependent is inferred
among `a`, `c`, `dh`, and `tmp1`.

The independent oracle models the component products, including the strided
section in `v100`, and the assignments in `v263` before its write through an
unallocated `tmp1`. It checks finite-difference JVP/VJP adjoint identities and
does not read transformed output or claim exact-source derivative support.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next40/record.py \
  --raw /var/tmp/ert/fortad-bench-next40/set05-v098/raw.json \
  --raw /var/tmp/ert/fortad-bench-next40/set05-v099/raw.json \
  --raw /var/tmp/ert/fortad-bench-next40/set05-v100/raw.json \
  --raw /var/tmp/ert/fortad-bench-next40/set06-v263/raw.json
python3 cases/tapenade-queue-shard-next40/test_contract.py
```
