# Tapenade set01 `lh007`-`lh015` tranche: generated-compile boundaries

This tranche closes the next three strict pure-Fortran rows without rewriting
their Tapenade inputs. The runner compiles each pinned upstream primal and
stored reference, regenerates parser, tangent, and reverse files with the
pinned Tapenade executable, and compiles every fresh generated file under
strict GNU Fortran flags.

FortAD transforms the exact source as well. `lh012` and `lh013` produce a
compilable forward derivative but their reverse output is rejected by the
compiler. `lh014` relies on implicit typing for its loop index. FortAD emits
`implicit none` without declaring that index, so both generated modes are
rejected. The diagnostics are recorded rather than converted into support
claims.

The independent harness checks the intended algebra in safe, explicitly
initialized observations: indexed products for `lh012`, an initialized
`A(2)=2` observation for `lh013`, and the sum of the `lh014` output loop.
Each observation has a hand JVP/VJP, a central-difference sweep, and the
JVP/VJP adjoint identity. These checks do not erase the exact-source
initialization and implicit-typing boundaries.

Run locally:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh007_015.sh
```

The generated report is
[`results/tapenade_set01_lh007_015_refusal_validation.txt`](../../results/tapenade_set01_lh007_015_refusal_validation.txt).
