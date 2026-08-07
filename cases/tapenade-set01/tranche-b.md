# Tapenade set01 tranche B

This tranche audits the pinned `bd06` and `lh057` cases.

`lh057` is promoted as a runnable port. The upstream routine overwrites `a`
and `c`; the port exposes `a_out` and `c_out` explicitly, retaining both
assignments and the square-root domain. FortAD forward mode and both scalar
reverse dependents (`a_out` and `c_out`) are compiled and checked against
closed-form derivatives, a central-difference sweep, and adjoint identities.

`bd06` remains an explicit refusal boundary. Its unmodified forward transform
works, but the reverse transform rejects the one-trip loop with FortAD's
diagnostic that the loop carries no value across iterations. The strict
compiler and transform diagnostics are recorded; the row is not counted as a
support win.

Run [`bench_tapenade_set01_tranche_b.sh`](../../scripts/bench_tapenade_set01_tranche_b.sh)
after fetching the pinned checkout. The runner compiles all ten unmodified
upstream sources and stored derivative references with strict gfortran (using
Tapenade's checked-in `DIFFSIZES.f` as the include contract), then performs
the FortAD and oracle checks.
