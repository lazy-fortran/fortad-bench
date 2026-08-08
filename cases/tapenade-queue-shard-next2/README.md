# Tapenade Fortran modern-feature queue shard: next2

This new shard closes four disjoint pure-Fortran rows: `set11/vpf19`
(`some_type2_difference`, score 154), `set07/v479` (`ainit`, 145),
`set04/lh111` (`allocg`, 130), and `set07/v520` (`calc_force`, 122). They are
compiler-clean, free-form, and have no unresolved include or dependency hints.
The fixed modern-feature weights are `abstract=20`, `polymorphic=18`,
`select type=18`, `class(`=16, `allocatable=14`, `pointer=14`, `associate=12`,
`do concurrent/coarray/codimension=12`, `contiguous=10`, `derived/type ::`=10,
`type(`/`procedure`/`recursive`=8, `elemental/pure/final=7`, `generic=6`,
`interface/bind(c)/iso_c_binding=5`, `optional=4`, and `dimension=3`.

Exact primary/reference sources are hash-verified, and each exact source is
strict-compiled. Fresh pinned Tapenade parser/tangent/reverse probes pass at
the engine boundary. FortAD records deliberate boundaries for nested active
derived components, global mutable module state, pointer-association lifetime,
and allocatable derived-component state. The independent oracle is separate
from the engine result and makes no derivative-support claim.

`mvo33` was not used: its top static hint `fun` is only an abstract-interface
declaration, and Tapenade silently falls back to another root. It therefore
does not satisfy a valid exact root probe.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next2/record.py \
  --raw /var/tmp/fortad-bench-shard-next-vpf19/raw.json \
  --raw /var/tmp/fortad-bench-shard-next-v479/raw.json \
  --raw /var/tmp/fortad-bench-shard-next-lh111/raw.json \
  --raw /var/tmp/fortad-bench-shard-next-v520/raw.json
python3 cases/tapenade-queue-shard-next2/test_contract.py
```
