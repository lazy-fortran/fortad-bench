# Tapenade Fortran modern-feature queue shard: next49

Next49 closes 48 previously unclassified, pure-Fortran, compiler-clean,
dependency-safe, free-form callable procedure roots after next48. Selection uses
the fixed case-insensitive modern-feature score, descending score, then
committed queue order for ties. The selected roots and exact score features
are recorded in `manifest.toml`; the score bands are 14 (2 roots), 12 (1),
10 (4), 9 (11), 8 (10), 6 (19), and 4 (1).

Tapenade passes parser, forward, and reverse generation for all 48 exact roots
at pinned upstream `e59864c…`. Current FortAD `2636206…` produces all three
products for 14 cases; the other 34 retain phase-specific refusal diagnostics.
These are explicit boundaries, including OpenMP, COMMON or module-global
state, derived components, array rank, intrinsic rules, call mapping, I/O,
and dependent inference. Legacy/global-state refusals are not counted as
product failures.

The 14 generated-product cases have independent finite-difference/adjoint or
bounded source-map oracles. The other 34 have independent refusal oracles.
Neither class reads transformed output or claims runtime derivative support.
`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
phase commands and diagnostics, generated-source checks, and pinned revisions.

Rebuild the canonical evidence after rerunning the exact roots with the probe
command in `manifest.toml`:

```bash
python3 cases/tapenade-queue-shard-next49/record.py \
  --raw /var/tmp/fortad-bench-next49-*.json
python3 cases/tapenade-queue-shard-next49/test_contract.py
```
