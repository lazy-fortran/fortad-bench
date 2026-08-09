# Tapenade Fortran modern-feature queue shard: next29

Next29 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next28. They are ordered by
the fixed modern-feature score, descending score and then committed queue
order for ties:

| row | root | score | features | exact FortAD boundary |
|---|---|---:|---|---|
| `set10/lh221` | `flottab_1d` | 30 | `dimension=10` | unsupported module array section |
| `set07/v526` | `foo` | 28 | `pointer=1; type(=1; dimension=2` | same-file procedure-call actual mapping |
| `set03/lh097` | `top` | 27 | `type(=3; dimension=1` | reverse dependent inference |
| `set05/v178` | `lbc_lnk_2d` | 27 | `type(=1; interface=2; dimension=3` | reverse dependent inference |

The exact pinned Tapenade revision is `e59864c`; probes use the FortAD
executable at revision `f3ee376`. Tapenade parser, forward, and reverse probes
pass for all four exact roots. FortAD refuses all three modes for `lh221` and
`v526`; parser and forward pass while reverse refuses for `lh097` and `v178`
because no dependent can be inferred. No row is classified as invalid-upstream.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, and independent bounded
behavior/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next29/record.py \
  --raw /var/tmp/fortad-bench-next29-lh221.raw.json \
  --raw /var/tmp/fortad-bench-next29-v526.raw.json \
  --raw /var/tmp/fortad-bench-next29-lh097.raw.json \
  --raw /var/tmp/fortad-bench-next29-v178.raw.json
python3 cases/tapenade-queue-shard-next29/test_contract.py
```
