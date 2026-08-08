# Tapenade Fortran modern-feature queue shard: next11

This shard closes the next four disjoint pure-Fortran, compiler-clean,
dependency-free procedure rows after next10. The fixed case-insensitive score
selects `set03/cm31` and `set03/cm32` (66 each), `set05/v194` (63), and
`set06/v351` (62), with ties resolved by committed queue order.

Fresh pinned Tapenade parser, forward, and reverse products are recorded. FortAD
refuses the pointer-allocation, module allocatable-state, and generic-MINVAL
boundaries. The v194 parser and forward products are emitted; its exact reverse
command refuses because the multi-output `head` has no inferred dependent. This
is not classified as invalid upstream. Independent oracles cover the exact
allocation, FORALL, and MINVAL primal behavior without derivative claims.

Rebuild and check with:

```bash
python3 cases/tapenade-queue-shard-next11/record.py \
  --raw /var/tmp/fortad-next11-cm31/raw.json \
  --raw /var/tmp/fortad-next11-cm32/raw.json \
  --raw /var/tmp/fortad-next11-v194/raw.json \
  --raw /var/tmp/fortad-next11-v351/raw.json
python3 cases/tapenade-queue-shard-next11/test_contract.py
```
