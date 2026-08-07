# Tapenade set02 `v128`: exponential scalar output

The pinned source is a small fixed-form procedure:

```fortran
subroutine foo(n,x,y)
  y = exp(-0.5*x(1))
end
```

It has one local `DIFFSIZES.inc` include used only by the stored
multidirectional reference. The include is present in the same pinned case
directory and does not introduce a mixed-language dependency.

The runner compiles the exact primal and stored reference, regenerates parser,
tangent, and reverse products with Tapenade at the pinned revision, and
compiles every fresh product under strict fixed-form flags. FortAD is then
run on the unchanged exact source in forward and reverse mode; those products
are compiled and executed by the case harness.

The independent oracle checks `y = exp(-0.5*x(1))`, its hand JVP and VJP, a
central-difference sweep, and the JVP/VJP adjoint identity. It does not inspect
generated source or treat a successful process exit as a correctness oracle.

Run it with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set02/v128/run.sh
```
