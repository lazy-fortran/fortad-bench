# Tapenade Fortran modern-feature queue shard: next51

Next51 closes the next 48 non-overlapping, pure-Fortran, compiler-clean,
dependency-safe, free-form callable roots after next50. The fixed
case-insensitive modern-feature score has reached zero for the remaining
eligible queue, so these roots are selected in committed queue order. Program
category rows are included only where exact source inspection found a callable
procedure root.

Pinned Tapenade passes parser, forward, and reverse generation for all 48
exact roots. Current FortAD and FortFront pins are recorded in the manifest;
FortAD emits all three products for four roots and preserves explicit refusal
diagnostics for the other 44. Global mutable state, COMMON/module legacy
boundaries, I/O, ENTRY/DATA/directive legacy constructs, call mapping,
dependent inference, character handling, and unsupported expressions are
intentional evidence boundaries, not product failures.

The four generated-product cases have independent bounded source-map oracles.
The other 44 have independent refusal oracles. Neither class reads transformed
output or claims runtime derivative support. `result.json` retains exact
source/reference SHA-256 hashes, compiler evidence, phase commands and
diagnostics, generated-source checks, and pinned engine revisions.

Rebuild the canonical evidence with one `--raw PATH` argument per raw record;
run `test_contract.py` after supplying all 48 records.
