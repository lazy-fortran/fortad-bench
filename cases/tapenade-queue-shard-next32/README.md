# Tapenade Fortran modern-feature queue shard: next32

Next32 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next31. They are ordered by
the fixed modern-feature score, descending score and then committed queue order
for ties:

| row | root | score | features | exact FortAD boundary |
|---|---|---:|---|---|
| `set03/lh094` | `top` | 20 | `type(=1; dimension=4` | derived-type-containing root at line 1 |
| `set04/ptr09` | `test` | 20 | `pointer=1; dimension=2` | pointer-association storage identity |
| `set06/v222` | `test1` | 20 | `interface/bind(c)/iso_c_binding=4` | local interface statement at line 25 |
| `set07/v436` | `test` | 20 | `pointer=1; dimension=2` | derived pointer component at line 1 |

The exact pinned Tapenade revision is `e59864c`; probes use the FortAD
executable at revision `14883b8`. Tapenade parser, forward, and reverse probes
pass for all four exact roots. FortAD records the boundaries above. No row is
classified as invalid upstream; each local refusal is explicitly not an
upstream-validity claim.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, and independent bounded
behavior/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next32/record.py \
  --raw /var/tmp/fortad-bench-next32-lh094-top/raw.json \
  --raw /var/tmp/fortad-bench-next32-ptr09-test/raw.json \
  --raw /var/tmp/fortad-bench-next32-v222-test1/raw.json \
  --raw /var/tmp/fortad-bench-next32-v436-test/raw.json
python3 cases/tapenade-queue-shard-next32/test_contract.py
```
