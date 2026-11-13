# Tapenade Fortran queue shard: next53

Next53 selects 48 previously unclassified, pure-Fortran, compiler-clean,
dependency-safe callable roots after next52. The 17 remaining free-form roots
are selected first in committed queue order; 31 fixed-form callable roots then
fill the shard in the same queue order. Program-only rows without a callable
procedure root are excluded, not labeled invalid upstream.

The manifest pins Tapenade, FortAD, and FortFront revisions. The probe runs
Tapenade parser/forward/reverse and FortAD parser/forward/reverse against the
exact fetched sources. `result.json` retains source/reference hashes, compiler
evidence, commands, phase diagnostics, generated-source checks, and
independent bounded source/refusal oracles. No generated product receives a
runtime derivative claim without an independent source map.

Tapenade passes all three modes for all 48 roots. Current FortAD emits all
three products for 6 roots and records explicit phase-specific refusals for
42. The six generated-product cases remain no-runtime-claim evidence; the
other 42 have independent refusal oracles.

Rebuild the canonical evidence with one `--raw PATH` argument per raw probe;
run `test_contract.py` after all 48 records are supplied.
