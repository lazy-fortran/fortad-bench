# Tapenade Fortran modern-feature queue shard: next4

This shard closes four disjoint pure-Fortran, compiler-clean queue rows:
`set06/v342` (`p1`, score 84), `set12/mvo33` (`type_set_func`, 74),
`set11/vpf09` (`foo`, 67), and `set06/v335` (`test`, 32). They are exact
source roots not used by the next, next2, or next3 shards, selected from the
branch-base queue by the committed modern-feature score.

The rows cover pointer components and module-use chains, abstract-interface
procedure pointers, contiguous pointer/assumed-shape declarations, and
allocatable/pointer/optional dummy declarations. Fresh Tapenade parser,
forward, and reverse probes pass for every root. FortAD records the exact
unsupported boundary for each root; parser mode is accepted for v335 while
its forward and reverse modes require explicit independent variables.

Each exact source/reference is compiler-clean in the branch-base batch
evidence and hash-recorded in `result.json`. The separate Python oracle models
the primal storage or dispatch behavior and the corresponding derivative or
refusal boundary without invoking either transformation tool.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next4/record.py \
  --raw /var/tmp/fortad-bench-next4-v342-p1-2/raw.json \
  --raw /var/tmp/fortad-bench-next4-mvo33-type-set-func/raw.json \
  --raw /var/tmp/fortad-bench-next4-vpf09-foo2/raw.json \
  --raw /var/tmp/fortad-bench-next4-v335-test2/raw.json
python3 cases/tapenade-queue-shard-next4/test_contract.py
```
