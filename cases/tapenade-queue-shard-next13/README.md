# Tapenade Fortran modern-feature queue shard: next13

This shard closes the next four disjoint pure-Fortran, compiler-clean,
dependency-free procedure rows after next12. The fixed case-insensitive score
selects `set06/v364` (`test`, 56), `set04/lh112` (`top`, 55), `set03/lh051`
(`top`, 52), and `set03/cm25` (`top`, 50), with ties resolved by committed
queue order.

Fresh pinned Tapenade parser, forward, and reverse products are recorded.
FortAD records linked-list pointer association, derived-array TARGET alias,
TARGET/P pointer alias, and derived-component pointer allocation boundaries.
The independent Python oracles model the defined primal/storage behavior and
the refusal boundary without claiming derivative support. No row is classified
as invalid upstream.

Rebuild and check with:

```bash
python3 cases/tapenade-queue-shard-next13/record.py \
  --raw /var/tmp/fortad-next13-v364/raw.json \
  --raw /var/tmp/fortad-next13-lh112/raw.json \
  --raw /var/tmp/fortad-next13-lh051/raw.json \
  --raw /var/tmp/fortad-next13-cm25/raw.json
python3 cases/tapenade-queue-shard-next13/test_contract.py
```
