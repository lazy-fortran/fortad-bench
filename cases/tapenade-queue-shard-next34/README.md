# Tapenade Fortran modern-feature queue shard: next34

Next34 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next33. They tie at the next
fixed modern-feature score, 17, and are ordered by committed queue order:

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `examples/big01/v235` | `satur_c` | 17 | `allocatable=1; dimension=1` | module-level allocatable mutable state |
| `set04/lh127` | `top` | 17 | `allocatable=1; dimension=1` | module-level allocatable `T` |
| `set04/lh134` | `bugalloc` | 17 | `allocatable=1; dimension=1` | reverse explicit deallocation lifetime |
| `set04/lh146` | `top` | 17 | `allocatable=1; dimension=1` | module-level allocatable `T` |

The exact pinned Tapenade revision is `e59864c`; the FortAD executable used for
this run is revision `8536c00`. Tapenade parser, forward, and reverse probes
pass for all four exact roots. FortAD deliberately refuses the three
module-state roots. For `lh134`, parser and forward products are emitted;
reverse is probed with explicit dependent `Y` and refuses at the local
allocatable deallocation lifetime. None is classified as invalid upstream.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, generated-source syntax checks, revision pins,
and independent behavioral/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next34/record.py \
  --raw /var/tmp/fortad-bench-next34-v235/raw.json \
  --raw /var/tmp/fortad-bench-next34-lh127/raw.json \
  --raw /var/tmp/fortad-bench-next34-lh134-explicit-upper/raw.json \
  --raw /var/tmp/fortad-bench-next34-lh146/raw.json
python3 cases/tapenade-queue-shard-next34/test_contract.py
```
