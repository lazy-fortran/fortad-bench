# Tapenade Fortran modern-feature queue shard: next35

Next35 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next34. They are ordered by
the fixed modern-feature score, descending score and then committed queue order
for ties:

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set06/v367` | `foo` | 38 | `allocatable=1; type(=3` | module-level allocatable and mutable state |
| `set06/v383` | `multipl` | 37 | `allocatable=2; dimension=3` | unsupported `.not.` active expression; saved state is later |
| `set11/lh050` | `sum_magnitude` | 33 | `allocatable=2; iso_c_binding=1` | parser product syntax-checks; forward/reverse generated interfaces fail strict detached checks |
| `set04/v046` | `test` | 32 | `procedure=1; elemental=2; interface=2` | parser/forward detached interfaces fail; reverse product syntax-checks |

The exact pinned Tapenade revision is `e59864c`; probes use FortAD revision
`6fd4136`. Tapenade parser, forward, and reverse probes pass for all four exact
roots. FortAD deliberately refuses `v367` at module-owned mutable state.
`v383` exposes a separate FortAD logical-expression support gap before its saved
allocatable state is reached. FortAD emits all three products for `lh050` and
`v046`, but detached strict syntax checks expose generated-interface/context
failures documented in `result.json`. The independent models check the two
stateful primal maps and independent complex/generic elemental JVP/VJP
identities; no exact-source derivative-support claim is made.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, generated-source syntax checks, revision pins,
and independent behavioral/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next35/record.py \
  --raw /var/tmp/fortad-bench-next35-v367/raw.json \
  --raw /var/tmp/fortad-bench-next35-v383/raw.json \
  --raw /var/tmp/fortad-bench-next35-lh050/raw.json \
  --raw /var/tmp/fortad-bench-next35-v046/raw.json
python3 cases/tapenade-queue-shard-next35/test_contract.py
```
