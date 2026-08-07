# Tapenade `todoF90/REFERENCES/v417`: allocatable-component boundary

`v417` contains the free-form modules `param_m`, `struc_m`, and `calc_m`.
The selected procedure is `calc_force(geom,prop,obj,acc)`.  Its live
calculation uses the allocatable `geom%vol` and `prop%den` components, computes
the `acc` array and `obj%force`, and resets `obj%acc` to zero.  The local
smoothed `vol` array is computed but is dead after that loop.

The exact primal and the stored association-by-address tangent
`program_Rd.f90` both compile with strict Fortran 2018 flags.  The stored
`program_Rd.msg` records the historical circular-dependence and `continue`
tangent diagnostics; it is retained as evidence rather than regenerated or
repaired.

Fresh generation from the pinned Tapenade checkout, using the retained
`-association byaddress` option and root `calc_force`, succeeds for parser,
tangent, and reverse modes.  Every fresh output compiles strictly.  This is
recorded separately from the stored reference.

FortAD's exact parser, forward, and reverse requests all refuse at line 17,
the first allocatable component declaration, with
`unsupported allocation lifetime construct 'allocatable declaration/component'`.
No output file is written.  This is the exact boundary; changing the derived
types to fixed-size arrays would be a different program, so no bounded port is
claimed.

`oracle.py` is independent of the compiler, Tapenade, and FortAD.  It models
the live scalar/array equations on a nonzero domain, checks a hand JVP against
central differences, and checks the matching hand VJP using the adjoint
identity.  The dead smoothing loop is intentionally absent from the model
because it cannot affect any result of the source procedure.

Run the complete probe from the worker worktree with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v417/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v417/test_contract.py
```

`result.txt` records the strict compiler gates, fresh pinned Tapenade
generation and compilation, exact FortAD refusal diagnostics, independent
oracle values, and hashes for every pinned v417 reference.
