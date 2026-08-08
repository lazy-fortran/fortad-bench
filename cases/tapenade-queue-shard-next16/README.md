# Tapenade Fortran modern-feature queue shard: next16

This shard closes four disjoint pure-Fortran candidates selected in committed
queue order after requiring a free-form, dependency-free source with an
explicit function or subroutine root and strict/legacy exact-source checks:
`set03/cm05` (`foo`), `set03/cm10` (`allocateTata`), `set03/cm34`
(`allocateToto`), and `set03/lh013` (`function`). Program-only rows are not
silently turned into derivative roots; the selection rule records why they are
skipped.

The cases cover a pointer-valued function result, pointer-component allocation
and deallocation, a derived pointer/allocatable graph with module-level mutable
state, and a componentwise derived-type affine procedure. Fresh Tapenade
revision `e59864c` emits parser/forward/reverse products for all four roots.
FortAD deliberately refuses the first three at explicit pointer ownership or
global-state boundaries. The `lh013` products compile and pass an independent
hand JVP/VJP oracle.

The three refusals are intentional support-contract results: FortAD must not
invent derivatives for pointer identity, allocation ownership, or module-level
mutable state. They are not invalid upstream sources, missing dependencies, or
silent failures.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next16/record.py \
  --raw /var/tmp/fortad-bench-next16-run-zHDS64/nonRegressions_set03_cm05__foo/raw.json \
  --raw /var/tmp/fortad-bench-next16-run-zHDS64/nonRegressions_set03_cm10__allocatetata/raw.json \
  --raw /var/tmp/fortad-bench-next16-run-zHDS64/nonRegressions_set03_cm34__allocatetoto/raw.json \
  --raw /var/tmp/fortad-bench-next16-run-zHDS64/nonRegressions_set03_lh013__function/raw.json
python3 cases/tapenade-queue-shard-next16/test_contract.py
```
