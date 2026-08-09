# Tapenade Fortran modern-feature queue shard: next42

Next42 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form procedure candidates after next41. Selection uses the fixed
case-insensitive modern-feature score, descending score, then committed queue
order for ties. The four remaining score-16 leaders are genuine derived-type
boundaries:

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set03/lh068` | `top` | 16 | `type(=2` | generated derived-record context is not standalone-strict; reverse has three derived dependents |
| `set04/v002` | `dot_prod` | 16 | `type(=2` | all commands generate, but standalone products have a derived-type/module interface boundary |
| `set04/v003` | `test` | 16 | `type(=2` | active `PRINT` at line 15 |
| `set04/v012` | `t` | 16 | `type(=2` | generated products require the local `defpoint` module; reverse has two derived dependents |

The exact pinned Tapenade revision is `e59864c`; fresh probes use FortAD
revision `386706b`. Tapenade parser, forward, and reverse products pass for
all four exact roots. FortAD generates parser/forward products for `lh068` and
`v012`, then records their standalone module/derived-type context boundary;
`v002` generates all three products but each fails the standalone strict-syntax
check. `v003` refuses all three modes at its active I/O statement. The reverse
refusals for `lh068` and `v012` are recorded separately as dependent-inference
evidence. These are product boundaries, not invalid-upstream closures.

The independent oracle models the bounded `v -> v**2` map in `lh068`, a
three-component vector dot product in `v002`, the numeric component sum in
`v003` with its printed names omitted, and the defined components of the point
map in `v012`. It checks finite-difference JVP/VJP adjoint identities without
reading Tapenade or FortAD output and records the exact refusal boundary
separately; it makes no exact-source derivative-support claim.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next42/record.py \
  --raw /var/tmp/ert/fortad-bench-next42-lh068/raw.json \
  --raw /var/tmp/ert/fortad-bench-next42-v002/raw.json \
  --raw /var/tmp/ert/fortad-bench-next42-v003/raw.json \
  --raw /var/tmp/ert/fortad-bench-next42-v012/raw.json
python3 cases/tapenade-queue-shard-next42/test_contract.py
```
