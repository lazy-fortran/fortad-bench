# Tapenade Fortran queue shard: next52

Next52 closes the next 48 non-overlapping, pure-Fortran, compiler-clean,
dependency-safe, free-form callable procedure roots after next51. All selected
roots have score 0, so the cutoff is the committed queue order after excluding
program-only rows without a callable procedure root.

Pinned Tapenade passes parser, forward, and reverse generation for all 48 exact
roots. Current FortAD emits all three products for 16 roots and preserves
explicit phase diagnostics for the other 32. These are bounded feature and
language-boundary results: global mutable state, invalid generated interfaces,
dependent inference, intrinsic/call rules, control flow, and other refusals are
not repaired or relabeled as upstream failures.

The 16 generated-product cases have independent bounded source-map oracles.
The other 32 have independent refusal oracles. Neither class reads transformed
output or claims runtime derivative support. `result.json` retains exact
source/reference SHA-256 hashes, compiler evidence, phase commands and
diagnostics, generated-source checks, and pinned engine revisions.

Rebuild the canonical evidence with one `--raw PATH` argument per raw record;
run `test_contract.py` after supplying all 48 records.
