# Tapenade set01 tranche L: nested calls and split boundaries

This tranche promotes three small strict-Fortran regressions.

- `bd01` retains the nested `toto` computation and the in-place state updates
  after the call. Its independent inputs are `x`, `y`, and `z`. The useful
  reverse dependent is the nested-call result `w`.
- `bd02` retains the `toto` to `titi` assignment call.
- `bd03` retains the `g` to `f` call boundary that exercises Tapenade's split
  regression.

The [manifest](tranche-l-bd-ht-manifest.toml) pins the exact upstream paths and
entry points. The [runner](../../scripts/bench_tapenade_set01_tranche_l_bd_ht.sh)
compiles every unmodified upstream source, runs fresh Tapenade parser,
tangent, and adjoint generation, strictly compiles those outputs, then runs
FortAD forward and reverse transforms. An independent Fortran harness checks
hand JVP/VJP values, a four-step central-difference sweep, and the JVP/VJP
adjoint identity for each case.

Run it after fetching Tapenade (the runner builds its Gradle jar when absent):

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_l_bd_ht.sh
```
