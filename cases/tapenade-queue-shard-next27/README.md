# Tapenade Fortran modern-feature queue shard: next27

Next27 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next26, selected by the fixed
modern-feature score in descending order and committed queue order for ties:

| row | root | score | features | exact evidence boundary |
|---|---|---:|---|---|
| `set07/v434` | `test1` | 34 | `pointer=2; dimension=2` | pointer-association storage identity |
| `set07/v542` | `test` | 34 | `allocatable=2; dimension=2` | explicit allocatable deallocation lifetime |
| `set04/lh107` | `foo` | 33 | `allocatable=1; type(=2; dimension=1` | module-level allocatable derived state |
| `set05/v152` | `test` | 32 | `allocatable=1; pointer=1; optional=1` | no defined numeric output map |

The exact pinned Tapenade revision is `e59864c`; the FortAD probe build is
revision `f878b96`. Tapenade passes parser, forward, and reverse probes for
all four exact roots. FortAD refuses all three modes for `v434` and `lh107`.
For `v542`, parser and forward pass while an explicit reverse probe with
dependent `rr` refuses at `deallocate(x)`. For `v152`, explicit dependent `v`
makes all three FortAD commands pass, but the exact source never assigns its
output; it is recorded as an `expected-refusal` evidence boundary, not a
support claim. No row is classified as invalid upstream.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, and independent oracle output.
Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next27/record.py \
  --raw /var/tmp/fortad-bench-next27-v434.raw.json \
  --raw /var/tmp/fortad-bench-next27-v542-explicit.raw.json \
  --raw /var/tmp/fortad-bench-next27-lh107.raw.json \
  --raw /var/tmp/fortad-bench-next27-v152-explicit.raw.json
python3 cases/tapenade-queue-shard-next27/test_contract.py
```
