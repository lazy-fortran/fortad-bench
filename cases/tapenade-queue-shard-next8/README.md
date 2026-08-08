# Tapenade Fortran modern-feature queue shard: next8

This shard closes four disjoint pure-Fortran, compiler-clean procedure rows:
`set03/cmv07` (`intini`, score 92), `set10/lh234` (`head`, 86),
`set06/v237` (`bcfarfieldadj`, 84), and `set03/cm30` (`top`, 82). They are
the next exact roots selected from the branch-base queue by the fixed
case-insensitive modern-feature score, descending score then queue order, after
excluding every existing queue shard.

The exact primary and reference sources are strict- and legacy-compiled and
hash-recorded. Fresh pinned Tapenade parser, forward, and reverse probes pass
at the command boundary for every root. FortAD records module-state,
derived-component, missing-dependent, and pointer-storage boundaries. The
independent Python oracles model the corresponding allocation, linked-list,
explicit-state, and pointer-lifetime semantics without making a derivative
support claim for the exact roots.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next8/record.py \
  --raw /var/tmp/fortad-bench-next8-cmv07/raw.json \
  --raw /var/tmp/fortad-bench-next8-lh234/raw.json \
  --raw /var/tmp/fortad-bench-next8-v237/raw.json \
  --raw /var/tmp/fortad-bench-next8-cm30/raw.json
python3 cases/tapenade-queue-shard-next8/test_contract.py
```
