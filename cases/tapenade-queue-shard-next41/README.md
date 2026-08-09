# Tapenade Fortran modern-feature queue shard: next41

Next41 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form procedure candidates after next40. Selection uses the fixed
case-insensitive modern-feature score, descending score, then committed queue
order for ties.

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set06/v371` | `top` | 17 | `allocatable=1; dimension=1` | module-level allocatable mutable state |
| `set06/v372` | `top` | 17 | `allocatable=1; dimension=1` | module-level allocatable mutable state |
| `set07/v396` | `top` | 17 | `allocatable=1; dimension=1` | module-level allocatable mutable state; exact source also uses `GLOBAL(0)` |
| `set07/v403` | `sub1` | 17 | `type(=1; dimension=3` | local derived-type declaration at line 1 |

The exact pinned Tapenade revision is `e59864c`; probes use FortAD revision
`98201ce`. Tapenade parser, forward, and reverse products pass for all four
roots. FortAD refuses all three modes for the first three roots at the
module-level allocatable mutable-state boundary and refuses all three modes for
`v403` at its local derived-type declaration. These are explicit product
boundaries, not support claims.

The independent oracle models only bounded intended arithmetic: the allocated
sine/sum maps in `v371` and `v372`, the state-free intended result in `v396`,
and the component product in `v403`. It checks finite-difference JVP/VJP
adjoint identities without reading transformed output, repairing the exact
source, or claiming exact-source derivative support.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next41/record.py \
  --raw /var/tmp/ert/fortad-bench-next41-v371/raw.json \
  --raw /var/tmp/ert/fortad-bench-next41-v372/raw.json \
  --raw /var/tmp/ert/fortad-bench-next41-v396/raw.json \
  --raw /var/tmp/ert/fortad-bench-next41-v403/raw.json
python3 cases/tapenade-queue-shard-next41/test_contract.py
```
