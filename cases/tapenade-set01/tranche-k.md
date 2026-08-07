# Tapenade set01 tranche K: exact-source refusal boundaries

Tranche K probes three strict pure-Fortran cases without rewriting their
inputs. Each run uses the pinned Tapenade checkout to generate fresh parser,
tangent, and reverse files, compiles those files with strict GNU Fortran
flags, and then asks FortAD to transform the same unmodified source.

The cases are intentionally recorded as refusals:

- `lh003` contains Tapenade's nonstandard `DO (N+10) TIMES` syntax. FortAD
  reports `unsupported statement at line 11`.
- `lh005` combines COMMON state, labeled DO loops, GOTO, and unit I/O. FortAD
  reports its exact internal unmatched-DO diagnostic at line 37.
- `lh006` contains an old escaped apostrophe in a fixed-form character
  literal. FortAD reports the exact unterminated-character diagnostic at line
  49.

The independent harness does not claim support for the original I/O or COMMON
contracts. It checks small source-equivalent observations: a safe fixed-trip
model and hand tangent for `lh003`, branch derivatives of `x(1)` for `lh005`,
and a fixed-trace recurrence for `lh006`. Central differences must agree with
those hand derivatives before the refusal record is accepted.

Run with the local study checkouts:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_k.sh
```

The generated report is
[`results/tapenade_set01_tranche_k_refusal_validation.txt`](../../results/tapenade_set01_tranche_k_refusal_validation.txt).
