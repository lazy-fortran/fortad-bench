# Tapenade Fortran modern-feature queue shard: follow-up

This shard closes the next four pure-Fortran queue candidates selected by the
existing modern-feature workflow. Candidates are compiler-clean, free-form,
dependency-free procedure rows scored from case-insensitive occurrences in the
exact primary source, then tied by committed queue order. The fixed weights are
`abstract=20`, `polymorphic=18`, `select type=18`, `class(`=16,
`allocatable=14`, `pointer=14`, `associate=12`,
`do concurrent/coarray/codimension=12`, `contiguous=10`, `derived/type ::`=10,
`type(`/`procedure`/`recursive`=8, `elemental/pure/final=7`, `generic=6`,
`interface/bind(c)/iso_c_binding=5`, `optional=4`, and `dimension=3`.

The selected rows are `set04/v030` (`interval_addition`, score 210),
`set07/v534` (`testallocs`, score 165), `set12/mvo34` (`type_set_func`, score
165), and `set07/v535` (`testallocs`, score 159). Tapenade accepts all three
requested modes for the exact sources. FortAD records a parser-supported but
forward/reverse-refused derived-type boundary for `v030`, pointer ownership
refusals for `v534` and `v535`, and a polymorphic procedure-pointer refusal for
`mvo34`.

`oracle.py` is independent of the upstream sources and generated products. It
checks the interval arithmetic, pointer-owner mutation/deallocation, and
polymorphic dispatch primals together with the expected refusal boundary. It
makes no derivative-support claim for these cases.

The manifest pins Tapenade `e59864c` and FortAD `13b7ae1`, and records both the
selection-base and post-closure queue/batch hashes. Rebuild the canonical
evidence with:

```bash
python3 cases/tapenade-queue-shard-modern-followup/record.py \
  --raw /var/tmp/fortad-bench-v030-probe.json \
  --raw /var/tmp/fortad-bench-v534-probe.json \
  --raw /var/tmp/fortad-bench-mvo34-probe.json \
  --raw /var/tmp/fortad-bench-v535-probe.json
python3 cases/tapenade-queue-shard-modern-followup/test_contract.py
```
