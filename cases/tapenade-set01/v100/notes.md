# Tapenade `todoF90/REFERENCES/v100`

This historical case contains the free-form procedure `head(x,y)`.  It
updates the one-element array `x` in place and then computes
`y(1)=MOD(x(1),2.0D0)`.  The exact source has tab characters in its leading
fixed-form-looking indentation.  Under the strict F2018 gate used by this
corpus, `gfortran -pedantic-errors` therefore rejects only the primal source
with the nonconforming-tab diagnostic.  The stored Tapenade forward and
reverse references compile strictly.

Fresh pinned Tapenade generation succeeds for `-p`, `-d -root head`, and
`-b -root head`; all three generated sources also compile strictly.  FortAD's
parser mode accepts the exact source and its generated parser file compiles.
Exact forward and reverse modes refuse at the active `MOD` call because the
pinned FortAD build has no derivative rule for `mod` and emits no derivative
file.  This is a FortAD capability boundary, not a claim that the upstream
source passes the strict compiler gate.

The bounded `port.f90` makes the in-place update explicit as `x_out` and
restricts the input to `0.2 < x_in(1) < 0.4`.  On this open interval,
`MOD(10*x_in,2)` is exactly `10*x_in-2`, so the port preserves both observable
outputs and has JVP/VJP factor 10 for the selected map `x_in -> y`.  The
independent Python oracle checks this equivalence, a central-difference sweep,
and the adjoint identity.  `hand.f90` and `harness.f90` provide an additional
compiled hand-vs-FortAD behavioral check for the bounded port.

Run the complete pinned probe with the shared, read-only upstream checkout:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v100/run.sh
python3 cases/tapenade-set01/v100/test_contract.py
```

The generated compiler, Tapenade, FortAD, oracle, and checksum record is in
[`result.txt`](result.txt).
