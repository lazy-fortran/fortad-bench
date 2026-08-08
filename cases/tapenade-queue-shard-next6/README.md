# Tapenade Fortran modern-feature queue shard: next6

This shard closes four disjoint pure-Fortran, compiler-clean queue rows:
`set11/lh011` (`foo`, score 117), `set04/lh156` (`persar`, 108),
`set07/v521` (`compute`, 105), and `set11/vpf17` (`foo`, 102). They are exact
source roots not used by the next, next2, next3, next4, or next5 shards,
selected from the branch-base queue by the fixed modern-feature score.

Every primary and reference source is hashed and checked in both strict
Fortran 2018 and legacy compatibility modes without modifying the upstream
checkout. Fresh pinned Tapenade parser, forward, and reverse probes pass at
the command boundary for every root. FortAD records deliberate boundaries:
module-level mutable state, pointer storage identity, missing reverse
dependents, and invalid generated nested-derived-type interfaces. The
independent Python oracles model each primal/derivative/refusal boundary and
make no unsupported derivative claim.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next6/record.py \
  --raw /var/tmp/fortad-bench-next6-set11-lh011.json \
  --raw /var/tmp/fortad-bench-next6-set04-lh156.json \
  --raw /var/tmp/fortad-bench-next6-set07-v521.json \
  --raw /var/tmp/fortad-bench-next6-set11-vpf17.json
python3 cases/tapenade-queue-shard-next6/test_contract.py
```
