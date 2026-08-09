# Tapenade Fortran modern-feature queue shard: next46

Next46 closes four previously unclassified, pure-Fortran, compiler-clean,
dependency-safe free-form procedure candidates after next45. Selection uses
the fixed case-insensitive score used by the earlier modern-feature shards:
`abstract=20`, `polymorphic=18`, `select type=18`, `class(`=16,
`allocatable=14`, `pointer=14`, `associate=12`,
`do concurrent/coarray/codimension=12`, `contiguous=10`, `derived/type ::`=10,
`type(`/`procedure`/`recursive`=8, `elemental/pure/final=7`, `generic=6`,
`interface/bind(c)/iso_c_binding=5`, `optional=4`, and `dimension=3`.

| row | root | score | feature | measured FortAD boundary |
|---|---|---:|---|---|
| `set04/v036` | `f` | 16 | `type(=2` | module-level mutable `x` |
| `set06/v274` | `f` | 16 | `type(=2` | module-level mutable `x` before implicit `f_cb` |
| `set06/v275` | `f` | 16 | `type(=2` | module-level mutable `x` |
| `set03/cm17` | `top` | 14 | `pointer=1` | pointer-association storage identity |

Fresh probes at pinned Tapenade `e59864c…` pass parser, forward, and reverse
for all four exact roots. FortAD `f47d42e…` refuses all three modes for every
root. The three interval cases are intentional global-mutable-state policy
boundaries. `v274` additionally calls `f_cb` without a definition in the exact
case, so its oracle models only the explicitly bounded lower component. `cm17`
has a bounded defined branch; unassociated-pointer branches are not repaired or
claimed.

The independent Python oracle reads no transformed output. It checks the
fixed-state interval arithmetic or the defined pointer branch and records the
refusal boundary separately from those bounded models. `result.json` retains
exact source/reference hashes, compiler evidence, revision pins, commands,
diagnostics, generated-source syntax checks, and oracle output.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next46/record.py \
  --raw /var/tmp/fortad-bench-next46-v036.json \
  --raw /var/tmp/fortad-bench-next46-v274.json \
  --raw /var/tmp/fortad-bench-next46-v275.json \
  --raw /var/tmp/fortad-bench-next46-cm17.json
python3 cases/tapenade-queue-shard-next46/test_contract.py
```
