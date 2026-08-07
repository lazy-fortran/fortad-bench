# Tapenade set01 tranche C

This tranche promotes `lh058`, Tapenade's dependency-free Euclidean norm:

```fortran
e = sqrt(sum((t - u)**2))
```

The port keeps the loop and scalar output while making the array arguments,
intents, and `real64` kind explicit. FortAD forward and reverse transforms are
checked against the closed-form JVP/VJP, a four-step central-difference sweep,
and the JVP/VJP adjoint identity. The test point has a nonzero norm so the
derivative is smooth; the zero-norm branch is deliberately outside this
positive support claim.

The runner also compiles the unmodified upstream primal and all four stored
derivative/reference sources with strict gfortran. `program_dv.f` uses
Tapenade's checked-in `DIFFSIZES.inc` include. Stored Tapenade derivatives are
provenance evidence only; the current Tapenade executable is not rerun.

Run:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_c.sh
```

The generated measurement is recorded in
[`results/tapenade_set01_tranche_c_validation.txt`](../../results/tapenade_set01_tranche_c_validation.txt).
