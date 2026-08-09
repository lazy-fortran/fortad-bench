# Tapenade Fortran modern-feature queue shard: next31

Next31 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next30. They are ordered by
the fixed modern-feature score, descending score and then committed queue order
for ties:

| row | root | score | features | exact FortAD boundary |
|---|---|---:|---|---|
| `set03/bd17` | `test3` | 26 | `procedure=2; interface=2` | no inferred reverse dependent |
| `set04/lh126` | `top` | 25 | `allocatable=1; procedure=1; dimension=1` | passed-procedure callback reads active module state |
| `set06/v254` | `test` | 24 | `associate=2` | no inferred independent variable through module aliases |
| `set05/v144` | `head` | 22 | `interface=2; dimension=4` | local interface statement |

The exact pinned Tapenade revision is `e59864c`; probes use the FortAD
executable at revision `f845a07`. Tapenade parser, forward, and reverse probes
pass for all four exact roots. FortAD records the boundaries above. No row is
classified as invalid upstream; the fourth row's FortAD interface refusal is
explicitly not an upstream-validity claim.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, and independent bounded
behavior/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next31/record.py \
  --raw /var/tmp/fortad-bench-next31-bd17-test3/raw.json \
  --raw /var/tmp/fortad-bench-next31-lh126-top/raw.json \
  --raw /var/tmp/fortad-bench-next31-v254-test/raw.json \
  --raw /var/tmp/fortad-bench-next31-v144-head/raw.json
python3 cases/tapenade-queue-shard-next31/test_contract.py
```
