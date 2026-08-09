# Tapenade Fortran modern-feature queue shard: next39

Next39 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form candidates after next38. Selection uses the fixed case-insensitive
modern-feature score, descending score, then committed queue order for ties.
The three higher-scoring program-only rows `set03/cm08`, `set03/cm06`, and
`set03/cm16` remain queued because no callable function or subroutine root was
available for the required three-mode probe.

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set10/v297` | `test1` | 20 | `interface=4` | reverse dependent inference in mutually recursive call graph |
| `set11/vpf06` | `head` | 20 | `interface=4` | reverse dependent inference with overloaded interfaces |
| `set05/v173` | `test1` | 18 | `dimension=6` | reverse generated scalar-to-array assignment is invalid |
| `set04/lh150` | `root` | 17 | `allocatable=1; dimension=1` | multiple local allocation objects are refused |

The exact pinned Tapenade revision is `e59864c`; probes use the FortAD
revision recorded in `result.json`. Tapenade parser, forward, and reverse
probes pass for all four roots. FortAD emits parser/forward products for
`v297` and `vpf06` but refuses reverse because no dependent is inferred. It
emits parser/forward products for `v173`, while its reverse product fails the
strict syntax check on a scalar-to-array assignment. It refuses all three
`lh150` modes at the local multiple-allocation lifetime boundary.

The independent oracle models the mutually recursive sign-flip map, the
double-precision quotient, the bounded `WHERE`/`SUM` array map, and the
allocate/fill/deallocate map. It checks finite-difference JVP/VJP adjoint
identities where a numerical map is defined and records the exact refusal or
no-runtime boundary without reading Tapenade or FortAD output.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next39/record.py \
  --raw /var/tmp/fortad-bench-next39-v297/raw.json \
  --raw /var/tmp/fortad-bench-next39-vpf06/raw.json \
  --raw /var/tmp/fortad-bench-next39-v173/raw.json \
  --raw /var/tmp/fortad-bench-next39-lh150/raw.json
python3 cases/tapenade-queue-shard-next39/test_contract.py
```
