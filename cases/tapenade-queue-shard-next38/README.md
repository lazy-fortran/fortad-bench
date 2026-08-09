# Tapenade Fortran modern-feature queue shard: next38

Next38 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form candidates after next37. Selection uses the fixed case-insensitive
modern-feature score, descending score, then committed queue order for ties.
The fixed weights are documented in the original modern-feature shard; the
exact matched counts are retained here so the selection is auditable. The
three higher-scoring program-only rows `set03/cm08`, `set03/cm06`, and
`set03/cm16` are intentionally skipped because no function or subroutine root
exists to probe.

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set10/lh215` | `foo` | 24 | `dimension=8` | reverse product has scalar `SUM`/rank syntax errors |
| `set10/lh216` | `foo` | 24 | `dimension=8` | parser/forward `SPREAD` support; reverse has no dependent |
| `set12/mvo11` | `BUG` | 24 | `interface=3; dimension=3` | local `INTERFACE` at line 12 |
| `set07/v472` | `compute` | 22 | `interface=2; dimension=4` | generated forward result interface is not strict Fortran |

The exact pinned Tapenade revision is `e59864c`; the probes use FortAD
`f47d42e4`. Tapenade parser, forward, and reverse probes pass for all four
roots. FortAD emits parser and forward products for `lh215` with a reverse
strict-syntax failure, emits parser and forward products for `lh216` through
the active `SPREAD` path but refuses its reverse dependent inference, refuses the
local interface in `mvo11`, and returns non-strict generated interfaces for
`v472`. The latter source also writes a module global accumulator; the
independent oracle records that policy-relevant state separately rather than
treating a generated-product pass as evidence of safe global-state
differentiation.

The independent oracle models the exact bounded array reductions and masks for
`lh215`/`lh216`, the constant nine-element `BUG` map for nonzero `DET`, and the
`compute` map plus its global accumulator. It checks finite-difference JVP/VJP
adjoint identities and does not read any transformation output.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, generated-source syntax checks, revision pins,
and independent oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next38/record.py \
  --raw /var/tmp/fortad-bench-next38-lh215/raw.json \
  --raw /var/tmp/fortad-bench-next38-lh216/raw.json \
  --raw /var/tmp/fortad-bench-next38-mvo11/raw.json \
  --raw /var/tmp/fortad-bench-next38-v472/raw.json
python3 cases/tapenade-queue-shard-next38/test_contract.py
```
