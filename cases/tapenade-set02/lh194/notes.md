# Tapenade set02 `lh194`

`lh194` is a fixed-form AMPI regression with `head(x,y)`, its stored forward
and reverse sources, and a `main` program. The pinned `Options` file points at
`../ADFirstAidKit/mpich/include` and `../ADFirstAidKit`, while the source files
include `ampi/ampif.h`.

The exact checkout contains `ADFirstAidKit/ampi/ampif.h`, but not
`ADFirstAidKit/mpich/include/mpif.h`. Direct strict F2018 and legacy fixed-form
compilation therefore fails at `ampi/ampif.h`. Supplying the real
`ADFirstAidKit` directory reaches its nested `include 'mpif.h'` and fails
there, in both modes and for all three exact source files.

This is dependency-blocked evidence, not an invalid-upstream result. The
source and dependency files remain unmodified; no synthetic MPI header,
Tapenade output, FortAD output, repaired port, or numerical oracle is claimed.

Run from the bench root after fetching the pinned checkout:

```sh
TAPENADE_REPO=/home/ert/code/lazy-fortran/.wt/luna-bench-lh194/upstream/tapenade \
  cases/tapenade-set02/lh194/run.sh
```
