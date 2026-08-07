# Tapenade `nonRegressions/set01/lh084`: fixed-form exact-source boundary

The pinned upstream directory contains the original fixed-form `program.f`, a
stored reverse derivative `program_b.f`, and its message file.  The primal
source has the default root `flw2d1col`, which calls `check`; its loop updates
`rh3` and `rh4` in place and accumulates `sq` from `pres(is1)+pres(is2)`.

Fresh Tapenade parser, forward, and reverse probes all succeed at the pinned
revision.  The parser emits `lh084_p.f`; the forward and reverse probes emit
`lh084_d.f` and `lh084_b.f`.  The fresh reverse body is byte-for-byte equal to
the stored `program_b.f` after normalizing only the generated Tapenade banner.
All fresh outputs and the stored reverse source compile in fixed-form legacy
mode.  The strict Fortran-2018 check is intentionally recorded separately:
both exact sources use the legacy `REAL*8` declaration and therefore trigger
the compiler's expected nonstandard-declaration diagnostic.

Current FortAD is tested against the exact upstream file, without rewriting it
to free form, changing the labeled `DO 30`, or inventing a driver.  Its parser,
forward, and reverse requests all refuse at the same labeled-DO boundary and
write no derivative output.  This is an exact-source support gap, not a claim
that the upstream algorithm is invalid or that a bounded port is equivalent.
The manifest records the former FortAD baseline `3a946d34` for comparison, but
the reproducible runner now pins the clean descendant
`7adc75030db3fa4422339d82d2725ae29ee13dac`; no repository checkout is rewritten
for this disjoint case.

`oracle.py` independently transcribes the primal recurrence, checks central
finite differences in several directions, and checks the reverse derivative's
adjoint identity against the mathematical Jacobian.  It does not parse or
execute generated FortAD/Tapenade code.

Run the complete evidence with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh084/run.sh
python3 cases/tapenade-set01/lh084/test_contract.py
```

Generated sources, compiler objects, FortAD output, and logs remain in a
disposable temporary directory.  Only this case directory is tracked.
