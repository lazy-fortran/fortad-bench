# Tapenade Fortran modern-feature queue shard: next43

Next43 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form procedure candidates after next42. Selection uses the fixed
case-insensitive modern-feature score, descending score, then committed queue
order for ties. The higher-scoring `cm08`, `cm06`, and `cm16` rows are
program-only and are excluded because the three-mode contract requires a
callable procedure root.

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set04/v018` | `test` | 16 | `type(=2` | active `PRINT` at line 18 |
| `set04/v043` | `ff` | 16 | `type(=2` | parser has an invalid generated interface; forward/reverse reject active derived object `t` |
| `set07/v496` | `top` | 16 | `interface=2; dimension=2` | local `INTERFACE` at line 12 |
| `set10/lh238` | `foo` | 16 | `type(=2` | derived-type declaration at line 1 |

The exact pinned Tapenade revision is `e59864c`; fresh probes use FortAD
revision `84a667a`. Tapenade parser, forward, and reverse products pass for
all four exact roots. FortAD refuses the parser/forward/reverse
transformation boundary for `v018`, `v496`, and `lh238` without emitting
products. For `v043`, FortAD emits a parser product, while forward and
reverse stop at the active derived component. The `v496` Tapenade forward and
reverse products also retain their required local module context in the
standalone syntax check. These are measured generated-interface/product
boundaries, not invalid-upstream closures.

The independent oracle models a bounded numeric component sum for `v018`, a
two-component derived-value sum for `v043`, a callback-style two-vector dot
product for the incomplete external-call boundary in `v496`, and the defined
`1.5*x` vector result for `lh238`. It checks finite-difference JVP/VJP
adjoint identities without reading Tapenade or FortAD output and records the
exact source refusal separately; it makes no derivative-support claim for a
refused exact source.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next43/record.py \
  --raw /var/tmp/fortad-bench-next43-v018-*/raw.json \
  --raw /var/tmp/fortad-bench-next43-v043-ff-*/raw.json \
  --raw /var/tmp/fortad-bench-next43-v496-*/raw.json \
  --raw /var/tmp/fortad-bench-next43-lh238-*/raw.json
python3 cases/tapenade-queue-shard-next43/test_contract.py
```
