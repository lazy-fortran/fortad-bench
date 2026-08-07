# Tapenade set01 `lh017`, `lh022`, and `lh028`

This tranche keeps the pinned upstream files untouched and records the
corresponding FortAD ports. `lh017` is a complete forward and reverse result.
its implicit branch state is made explicit in the port. `lh022` and `lh028`
have passing forward transforms and independent hand/finite-difference/adjoint
oracles, while reverse mode records two different exact FortAD boundaries:
per-iteration storage and loop control-flow reversal.

The runner fetches/builds the pinned Tapenade checkout when needed, generates
fresh parser, tangent, and reverse files, compiles each generated file with
strict GNU Fortran flags, probes FortAD, and runs the independent numerical
harness:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh017_032.sh
```

The committed report is
[`results/tapenade_set01_lh017_032_validation.txt`](../../results/tapenade_set01_lh017_032_validation.txt).
