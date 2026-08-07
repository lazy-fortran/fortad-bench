# Tapenade `todoF90/REFERENCES/v415`: allocatable-component refusal

`v415` is a single free-form source containing `param_m`, `struc_m`, and
`calc_m`.  The primal `calc_force(geom,prop,obj,acc)` uses allocatable
components in `geom_t` and `prop_t`, computes the live `acc` and `obj%force`
updates, and resets `obj%acc`.  Its local smoothed `vol` array is computed but
does not feed a later expression.

The exact primal compiles with strict F2018 flags.  The pinned stored
`program_d.f90` is preserved as an invalid historical derivative: its
generated `%v` accesses are applied to the non-derived `obj%acc`, `geom%vol`,
and `acc` components in the generated type definitions.  The stored
`program_d.msg` also records Tapenade's historical `continue` tangent
diagnostic.  This failure is evidence, not a reason to rewrite the upstream
source.

Fresh pinned Tapenade parser, tangent, and reverse generation with
`-root calc_force` all succeeds, and each fresh output compiles strictly.  The
fresh run is intentionally recorded separately from the invalid stored
derivative.

FortAD's exact `check`, forward, and reverse requests all stop at the same
allocatable declaration/component boundary and emit no derivative file.  No
bounded port is included: removing or replacing the allocatable derived-type
components would be a different program rather than a faithful specialization
of this case.

`oracle.py` is independent of the compiler, Tapenade, and FortAD.  It models
the live scalar/array arithmetic at a nonzero point, checks a hand-derived JVP
against central differences, and checks the corresponding hand VJP with an
adjoint dot-product identity.  The smoothed dead local is intentionally absent
from the model because it has no effect on the source's outputs.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v415/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v415/test_contract.py
```

`result.txt` records compiler statuses, fresh generated-file hashes, exact
FortAD refusal diagnostics, the independent oracle, and hashes of all pinned
v415 reference files.
