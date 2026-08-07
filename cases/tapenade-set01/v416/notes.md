# Tapenade `todoF90/REFERENCES/v416`: declaration-order boundary

`v416` contains the free-form `precechcin(x,y,nm_ha,Tm_ha)` routine, the
`association byaddress` option, and Tapenade's stored forward reference.  The
exact primal declares `MC_ha(nm_ha,nm_ha)` before declaring the dummy
`nm_ha`.  Strict F2018 gfortran therefore rejects the exact primal at that
declaration; this is the preserved exact-source boundary.  The stored
`program_Rd.f90` compiles strictly, with only the expected integer-division
warning from the source's `1/5/2.` assignment.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds.  Its
declaration pass moves `INTEGER nm_ha` above the explicit-shape array, so all
three fresh files strictly compile.  FortAD accepts all three exact requests:
its parser output retains the original declaration order and consequently
fails the same strict compiler gate, while its exact forward and reverse
outputs compile strictly.

The case includes a deliberately narrow standard-conforming port.  It changes
the declaration order and adds intents, but keeps the matrix initialization,
two passes, loop bounds, and final assignment.  The port's explicit domain is
`nm_ha >= 2`, so every indexed write remains valid, and `Tm_ha /= 0`, so the
source's divisions are defined.  For this domain `MC_ha(1,1)` is exactly one,
making the live map `y = x**2`; `Tm_ha` has zero derivative.  `harness.f90`
checks FortAD's generated JVP and VJP against that hand result, while
`oracle.py` independently models the matrix recurrence and checks central
differences plus the JVP/VJP adjoint identity.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v416/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v416/test_contract.py
```

`result.txt` records the exact compiler boundary, fresh generation and
strict-compilation results, exact FortAD behavior, bounded runtime, oracle,
and pinned-source checksums.  Generated files and compiler modules stay in a
disposable `/var/tmp` directory.
