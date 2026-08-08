# Tapenade Fortran modern-feature queue shard: next12

This shard closes the next four disjoint pure-Fortran, compiler-clean,
dependency-free procedure rows after next11. The fixed case-insensitive score
selects `set05/v058` (`test`, 67), `set05/v176` (`head`, 66), `set03/cmv04`
(`top`, 58), and `set05/v175` (`sub0`, 56), with ties resolved by committed
queue order.

Fresh pinned Tapenade parser, forward, and reverse products are recorded.
FortAD records the elemental generic-interface, COMMON/global-state, and
pointer-association boundaries. Independent Python oracles check the WHERE
and reciprocal semantics, generic swap composition, pointer-target product,
and swap state transitions without claiming derivative support for refused
source roots.

Rebuild and check with:

```bash
python3 cases/tapenade-queue-shard-next12/record.py \
  --raw /var/tmp/fortad-next12-v058/raw.json \
  --raw /var/tmp/fortad-next12-v176/raw.json \
  --raw /var/tmp/fortad-next12-cmv04/raw.json \
  --raw /var/tmp/fortad-next12-v175/raw.json
python3 cases/tapenade-queue-shard-next12/test_contract.py
```
