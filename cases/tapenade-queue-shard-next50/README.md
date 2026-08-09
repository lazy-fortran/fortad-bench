# Tapenade Fortran modern-feature queue shard: next50

Next50 closes 48 previously unclassified, pure-Fortran, compiler-clean,
dependency-safe, free-form callable procedure roots after next49. Selection
uses the fixed case-insensitive modern-feature score, descending score, then
committed queue order for ties: one score-4 root, 44 score-3 roots, and the
first three score-0 callable roots. Program-category rows are included only
after exact source inspection found a callable procedure root.

Tapenade passes parser, forward, and reverse generation for all 48 exact roots
at pinned upstream `e59864c…`. Current FortAD `65280f5…` emits all three
products for 14 cases; the other 34 retain full phase-specific refusal
diagnostics. OpenMP, I/O, global state, array-section, intrinsic, call-mapping,
callback, expression, and dependent-inference boundaries are intentional
evidence boundaries, not product failures.

The 14 generated-product cases have independent bounded source-map oracles.
The other 34 have independent refusal oracles. Neither class reads transformed
output or claims runtime derivative support. `result.json` retains exact
source/reference SHA-256 hashes, compiler evidence, phase commands and
diagnostics, generated-source checks, and pinned engine revisions.

Rebuild the canonical evidence with one `--raw PATH` argument per raw record;
run `test_contract.py` after supplying all 48 records.
