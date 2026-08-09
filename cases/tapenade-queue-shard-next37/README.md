# Tapenade Fortran modern-feature queue shard: next37

Next37 closes four disjoint, pure-Fortran, compiler-clean, dependency-safe,
free-form candidates after next36. Selection is by the fixed modern-feature
score, descending score, then committed queue order for ties:

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set05/v182` | `s` | 32 | `procedure=1; generic=1; interface=2` | active generic call has no derivative rule |
| `set07/v499` | `chars_to_integer` | 30 | `procedure=1; defined-assignment=1; interface=2` | formatted `READ` at line 13 |
| `set10/lh233` | `l2h1h2error` | 24 | `allocatable=1; module-state=1; array-section=2` | whole-file `END PROGRAM redmhd` layout at line 43 |
| `set11/vpf23` | `costlast` | 24 | `allocatable=1; dummy=2; external-call=1` | external `OPERATORS` call at line 19 |

The exact pinned Tapenade revision is `e59864c`; all fresh probes use FortAD
revision `6473ea1`. Tapenade parser, forward, and reverse probes pass for all
four roots. FortAD emits a strict-syntax-clean v182 parser product, then
refuses its generic call in forward/reverse. It refuses all three modes for the
formatted I/O, whole-file program-unit, and allocatable-dummy call boundaries.
None of these is an invalid-upstream classification.

The independent oracle checks generic dispatch plus finite-difference JVP/VJP
identities for v182, the defined `I5` conversion for v499, a bounded
single-call allocatable norm model for lh233, and the allocatable four-element
call map plus JVP/VJP identity for vpf23. It does not read transformation
output or claim derivative support for refused exact roots.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, generated-source syntax checks, revision pins,
and independent oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next37/record.py \
  --raw /var/tmp/fortad-bench-next37-set05-v182-r2/raw.json \
  --raw /var/tmp/fortad-bench-next37-set07-v499-r2/raw.json \
  --raw /var/tmp/fortad-bench-next37-set10-lh233-r2/raw.json \
  --raw /var/tmp/fortad-bench-next37-set11-vpf23-r2/raw.json
python3 cases/tapenade-queue-shard-next37/test_contract.py
```
