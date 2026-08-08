# Tapenade set02 `lh193`

`lh193` is a fixed-form AMPI regression with `head(x,y)` and a `main`
program. The pinned source includes `ampi/ampif.h`; its `Options` file points
at `../ADFirstAidKit`, but those paths do not exist relative to the case.

The exact checkout does contain `ADFirstAidKit/ampi/ampif.h`. Adding that
checkout directory to the strict fixed-form compiler search path reaches the
header's nested `include 'mpif.h'`, but the required
`ADFirstAidKit/mpich/include/mpif.h` is absent. Direct compilation therefore
fails at `ampi/ampif.h`, and the resolved-header control fails at `mpif.h`, in
both strict F2018 and legacy fixed-form modes.

This is dependency-blocked evidence, not an invalid-upstream result. The
source and dependency files remain unmodified; no synthetic MPI header,
Tapenade output, FortAD output, repaired port, or numerical oracle is claimed.

Run from the bench root after fetching the pinned checkout:

```sh
TAPENADE_REPO=/home/ert/code/lazy-fortran/.wt/luna-bench-lh193/upstream/tapenade \
  cases/tapenade-set02/lh193/run.sh
```
