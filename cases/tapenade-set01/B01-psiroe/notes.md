# B01-psiroe: exact B01 boundary case

This case preserves the pinned upstream directory
`upstream/tapenade/nonRegressions/set01/B01` exactly. The selected root is
`psiroe(ctrl,ctrlno)`, the first real source procedure in `program.f`. Its
direct call chain includes `GRADNOD`, `FLUROE`, `VCURVM`, `TRANSPIRATION`, and
`CONDDIRFLUX`; the file also contains the independent `GRADFB` tetrahedral
geometry helper.

Classification: `expected-refusal-fortad-unsupported-labeled-do-line-116`.

The exact source, stored forward reference, and stored reverse reference all
pass the legacy fixed-form syntax gate and fail the strict F2018 gate on the
upstream `REAL*8` declarations. The source is therefore not repaired or
ported. The upstream directory has no stored parser reference.

Fresh pinned Tapenade generation succeeds for all three explicit modes. The
commands are:

    tapenade -p -root psiroe -O OUT -o B01 upstream/tapenade/nonRegressions/set01/B01/program.f
    tapenade -d -root psiroe -O OUT -o B01 upstream/tapenade/nonRegressions/set01/B01/program.f
    tapenade -b -root psiroe -O OUT -o B01 upstream/tapenade/nonRegressions/set01/B01/program.f

The generated parser, forward, and reverse sources pass the legacy gate and
fail the strict gate for the same `REAL*8` reason.

FortAD is probed through its exact compatibility CLI, with the same explicit
root and options:

    fortad -p -root psiroe -O OUT -o B01 upstream/tapenade/nonRegressions/set01/B01/program.f
    fortad -d -root psiroe -O OUT -o B01 upstream/tapenade/nonRegressions/set01/B01/program.f
    fortad -b -root psiroe -O OUT -o B01 upstream/tapenade/nonRegressions/set01/B01/program.f

All three refuse without output. The parser reports that it could not locate
the end of the `DO 5` construct at source line 116. Forward and reverse reach
the same parser diagnostic while inferring their command arguments.

The independent oracle does not compile, repair, or execute a replacement
Fortran routine. It checks the exact source inventory and independently
recomputes the `GRADFB` six-volume determinant, a central-difference JVP, and
the scalar-output VJP dot-product identity for three geometries. Its result is
recorded by `run.sh` and exercised by the third contract test.
