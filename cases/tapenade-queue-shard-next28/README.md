# Tapenade Fortran modern-feature queue shard: next28

Next28 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next27, selected by the fixed
modern-feature score in descending order and committed queue order for ties:

| row | root | score | features | exact evidence boundary |
|---|---|---:|---|---|
| `set05/v086` | `surface` | 32 | `type(=4` | generated standalone interface syntax |
| `set03/cm04` | `foo` | 28 | `pointer=2` | pointer storage identity and target lifetime |
| `set05/v200` | `test` | 28 | `pointer=1; type(=1; dimension=2` | legacy derived-type pointer component |
| `set07/v483` | `top` | 28 | `allocatable=1; pointer=1` | module-level mutable allocatable state |

The exact pinned Tapenade revision is `e59864c`; the FortAD probe executable
was built at revision `076b7d8`. Tapenade parser, forward, and reverse probes
pass for all four exact roots. FortAD's three commands return products for
`v086`, but its generated standalone parser/forward/reverse sources fail the
strict syntax boundary; the record therefore makes no runtime or derivative-
support claim. FortAD refuses all three modes for `cm04`, `v200`, and `v483`
at their explicit pointer, derived-type, and module-state boundaries. No row
is classified as invalid-upstream.


`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, and independent bounded
behavior/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next28/record.py \
  --raw /var/tmp/fortad-bench-next28-v086.raw.json \
  --raw /var/tmp/fortad-bench-next28-cm04.raw.json \
  --raw /var/tmp/fortad-bench-next28-v200.raw.json \
  --raw /var/tmp/fortad-bench-next28-v483.raw.json
python3 cases/tapenade-queue-shard-next28/test_contract.py
```
