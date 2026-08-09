# Tapenade Fortran modern-feature queue shard: next48

Next48 closes exactly four previously unclassified, pure-Fortran,
compiler-clean, dependency-safe, free-form procedure candidates after
next47. Selection uses the fixed case-insensitive modern-feature score,
descending score, then committed queue order for ties.

The recorded probe base is FortAD `692f2e0`
(`692f2e0160bba00ac32a50a79f5bd2e8c3c68029`) with FortFront `6c27ca86`
(`6c27ca86a52066e46d318633febca52d41c106b6`).

| row | root | score | feature | measured FortAD boundary |
|---|---|---:|---|---|
| `set05/v153` | `test` | 14 | `pointer=1` | no active input/output; automatic independent inference |
| `set05/v155` | `g` | 11 | `type(=1; dimension=1` | derived-type constructor statement |
| `set06/v246` | `test` | 10 | `optional=1; dimension=2` | no defined function result or numeric map |
| `set06/v280` | `add` | 10 | `interface/bind(c)/iso_c_binding=2` | automatic independent inference |

Fresh automatic-fetch provenance at pinned Tapenade `e59864c…` passes parser,
forward, and reverse for all four exact roots. FortAD transforms all three
modes for `v246`. It emits the parser product for `v153` and `v280`, but their
forward/reverse probes refuse automatic independent inference; `v155` refuses
the derived-type constructor at parser and derivative generation. The exact
sources remain the authority: `v153` and `v246` define no numeric output map,
while the independent oracles check the identity map in `v155` and the
in-place affine map `b := b + a` in `v280` without reading transformed output.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
pinned upstream, FortAD, and FortFront revisions, engine commands and diagnostics,
generated-source syntax checks, and independent behavior/refusal output.
Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next48/record.py \
  --raw /var/tmp/fortad-bench-next48-v153.json \
  --raw /var/tmp/fortad-bench-next48-v155.json \
  --raw /var/tmp/fortad-bench-next48-v246.json \
  --raw /var/tmp/fortad-bench-next48-v280.json
python3 cases/tapenade-queue-shard-next48/test_contract.py
```
