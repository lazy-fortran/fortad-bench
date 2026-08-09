# Tapenade Fortran modern-feature queue shard: next30

Next30 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next29. They are ordered by
the fixed modern-feature score, descending score and then committed queue
order for ties:

| row | root | score | features | exact FortAD boundary |
|---|---|---:|---|---|
| `set04/lh162` | `top` | 25 | `pointer=1; type(=1; dimension=1` | same-file procedure-call actual mapping |
| `set06/v228` | `comp_maxdt` | 25 | `allocatable=1; type(=1; dimension=1` | module-level allocatable mutable state |
| `set03/lh043` | `foo` | 23 | `allocatable=1; dimension=3` | module-level allocatable mutable state |
| `set03/cm24` | `top` | 22 | `pointer=1; type(=1` | non-allocatable pointer-target lifetime |

The exact pinned Tapenade revision is `e59864c`; probes use the FortAD
executable at revision `ca66443`. Tapenade parser, forward, and reverse probes
pass for all four exact roots. FortAD parser, forward, and reverse modes
refuse for all four rows. No row is classified as invalid-upstream.
`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, and independent bounded
behavior/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next30/record.py \
  --raw /var/tmp/fortad-bench-next30-lh162/results.jsonl \
  --raw /var/tmp/fortad-bench-next30-v228/results.jsonl \
  --raw /var/tmp/fortad-bench-next30-lh043/results.jsonl \
  --raw /var/tmp/fortad-bench-next30-cm24/results.jsonl
python3 cases/tapenade-queue-shard-next30/test_contract.py
```
