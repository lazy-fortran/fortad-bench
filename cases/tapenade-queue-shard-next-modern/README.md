# Tapenade Fortran modern-feature queue shard

This shard closes four rows from the committed pure-Fortran queue: `set04/ptr08`,
`set04/ptr07`, `set06/v243`, and `set05/v180`. Selection is deterministic and
evidence-based: compiler-clean, free-form, dependency-free procedure candidates
are scored by case-insensitive modern-feature occurrences in their exact primary
source, then tied by committed queue order. Candidates have no unresolved include
or dependency risk; local `USE` modules are allowed. The fixed weights are: `abstract=20`,
`polymorphic=18`, `select type=18`, `class(`=16, `allocatable=14`, `pointer=14`,
`associate=12`, `do concurrent/coarray/codimension=12`, `contiguous=10`,
`derived/type ::`=10, `type(`/`procedure`/`recursive`=8, `elemental/pure/final=7`,
`generic=6`, `interface/bind(c)/iso_c_binding=5`, `optional=4`, and `dimension=3`.
The resulting scores are 197, 195, 192, and 149 respectively.
The exact matched feature counts are retained as `selection_features` in the
manifest and result, so the ranking is auditable without rerunning a heuristic
over a moving checkout.

The exact pinned Tapenade checkout is `e59864c`, and probes use FortAD
`159e38d`. Tapenade generates the three requested products for the pointer and
alias/lifetime cases, while FortAD records explicit ownership boundaries. The
`v180` root is a modern optional-rank/generic interface with no active numeric
map: FortAD parser/forward return zero, generated standalone procedures expose
the source-module context boundary, and reverse correctly refuses without an
inferred dependent. No repaired source or derivative-support claim is added.

`result.json` retains exact source/reference hashes, compiler evidence, engine
commands and bounded diagnostics, generated-source syntax checks, revision pins,
and the independent primal/source/refusal models. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next-modern/record.py \
  --raw /var/tmp/fortad-bench-queue-shard-next-ptr07-run2/raw.json \
  --raw /var/tmp/fortad-bench-queue-shard-next-ptr08-run2/raw.json \
  --raw /var/tmp/fortad-bench-queue-shard-next-v243-run2/raw.json \
  --raw /var/tmp/fortad-bench-queue-shard-next-v180-run2/raw.json
python3 cases/tapenade-queue-shard-next-modern/test_contract.py
```
