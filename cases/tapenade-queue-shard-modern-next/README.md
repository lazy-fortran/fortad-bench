# Tapenade Fortran modern-feature queue shard: next

This shard closes the next four pure-Fortran queue candidates selected by the
existing modern-feature workflow: compiler-clean, free-form, dependency-free
rows are scored from case-insensitive occurrences in the exact primary source,
then tied by committed queue order. The fixed weights are the ones documented
by the preceding modern shard: `abstract=20`, `polymorphic=18`, `select type=18`,
`class(`=16, `allocatable=14`, `pointer=14`, `associate=12`,
`do concurrent/coarray/codimension=12`, `contiguous=10`, `derived/type ::`=10,
`type(`/`procedure`/`recursive`=8, `elemental/pure/final=7`, `generic=6`,
`interface/bind(c)/iso_c_binding=5`, `optional=4`, and `dimension=3`.

The selected rows are `set06/v344` (`foo`, score 320),
`set12/f03typf02` (`foo`, score 270), `set12/mvo35` (`foo`, score 248), and
`set04/lh140` (`compute`, score 194). Their exact primary sources compile
with strict free-form Fortran. Tapenade parses and emits the requested
parser/forward/reverse products. FortAD records precise deliberate refusals:
nested pointer ownership, abstract/polymorphic module context, polymorphic
procedure-pointer dispatch, and pointer-association storage identity.

The independent oracle models each source-level dispatch or pointer-graph
primal behavior and checks the corresponding refusal boundary. It makes no
derivative-support claim for these pointer or dynamic-dispatch cases.

The probes use the pinned Tapenade and FortAD revisions in `manifest.toml` and
static entry points only. Rebuild the canonical evidence with:

```bash
python3 cases/tapenade-queue-shard-modern-next/record.py \
  --raw /var/tmp/fortad-bench-modern-next-v344-XXXX/raw.json \
  --raw /var/tmp/fortad-bench-modern-next-f03typf02-XXXX/raw.json \
  --raw /var/tmp/fortad-bench-modern-next-mvo35-XXXX/raw.json \
  --raw /var/tmp/fortad-bench-modern-next-lh140-XXXX/raw.json
python3 cases/tapenade-queue-shard-modern-next/test_contract.py
```
