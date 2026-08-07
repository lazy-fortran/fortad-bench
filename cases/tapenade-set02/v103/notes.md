# Tapenade set02 `v103`: exact COMMON-state refusal

`foo` copies a length-nine vector into a `COMMON /c/` 3-by-3 array, doubles
the array in place, and copies it back to `y`. The visible numerical map is
therefore `y = 2*x`, but the exact source's differentiable state is carried by
the COMMON block.

At the pinned Tapenade revision, the exact primal and stored references
compile, and fresh parser, tangent, and reverse products all compile strictly.
Current FortAD's check, forward, and reverse probes all refuse the unchanged
source at `COMMON /c/` line 32 with `unsupported statement`; no generated
FortAD source is retained or claimed. This is recorded as an exact-source
boundary, not hidden behind a guessed COMMON-to-local port.

The independent Python oracle models only the visible defined map `y=2*x` and
checks its hand JVP/VJP, central differences, and adjoint identity. That
oracle documents the case's behavior without converting the FortAD refusal
into a support result.

Run it with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set02/v103/run.sh
```
