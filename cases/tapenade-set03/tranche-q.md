# Tranche Q: `ht05`, `ht06`, `ht12`, and `ht13`

This tranche closes four disjoint pure-Fortran candidates from Tapenade's
`nonRegressions/set03`. The exact pinned upstream sources and stored references
are compiled and fresh Tapenade parser, tangent, and reverse outputs are
compiled under strict free-form flags.

`ht05` and `ht06` are exact-source FortAD refusals: allocation lifetime and an
array section are not represented by the current transform. `ht12` reaches
FortAD generation but its generated JVP and VJP do not compile: the JVP uses
the hidden extent before declaration and the VJP duplicates the adjoint dummy.
Those rows are recorded only as explicit refusal evidence.

`ht13` is a runnable exact-source case. Its JVP and VJP are checked against an
independent hand derivative, a central-difference sweep, and the scalar
adjoint identity.

```console
$ scripts/bench_tapenade_set03_tranche_q.sh
```
