# Tapenade set02 `v130`: saved scratch reset before a square

The exact fixed-form procedure clears its saved four-element scratch array,
adds `x*x` to its first entry, and returns that entry as `y`. The reset makes
the numerical contract `y = x**2` on every invocation, while still exercising
the saved-local declaration and loop.

The local `DIFFSIZES.inc` is required only by the stored multidirectional
reference and is not a mixed-language dependency. The runner compiles the
exact primal/reference, regenerates and strictly compiles all three pinned
Tapenade products, and probes the unchanged exact source with current FortAD
forward and reverse modes. Both FortAD products are linked into the case
harness.

The independent oracle checks the square's hand JVP/VJP, central differences,
and the adjoint identity over several signed inputs and directions.

Run it with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set02/v130/run.sh
```
