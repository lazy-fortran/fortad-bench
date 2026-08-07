# Tapenade set05 `v067`

`v067` is a measured modern-Fortran refusal, not a missing dependency and not a
promoted derivative port. The exact `RUN::s(mb1,mb2,mb3)` source and both stored
Tapenade references use legacy `REAL*8` declarations. The pinned files compile
with the legacy gfortran mode, but strict F2018 compilation rejects the
extension. This is an intentional boundary for FortAD's modern Fortran
contract; standardizing the declarations would change the exact source record.

Fresh pinned Tapenade parser, tangent, and reverse outputs are generated and
compile in legacy mode, while their strict compilation reproduces the same
`REAL*8` boundary. FortAD's exact parser extraction succeeds, but its forward
and reverse probes refuse the unresolved generic `FUNC` call and produce no
derivative source. No repaired source or numerical derivative claim is made.

The independent oracle checks the legacy control, strict refusal, and the
source invariants. The reproducible measurement is
[`v067_result.txt`](v067_result.txt).

Run from this repository root:

```sh
TAPENADE_REPO=/path/to/tapenade-at-e59864c \
FORTAD_REPO=/path/to/fortad-at-db0f3af \
  cases/tapenade-set05/v067_run.sh
```
