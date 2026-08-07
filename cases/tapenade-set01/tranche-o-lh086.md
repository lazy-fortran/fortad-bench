# Tranche O: `lh086`

`lh086` is Tapenade's Newton-iteration regression. The exact fixed-form
upstream routine updates `x` in place. FortAD's reverse interface cannot yet
represent a variable that is simultaneously the dependent and an independent,
so this case uses a bounded port with the same iteration map and an explicit
final-iterate output `y`.

The runner checks the exact upstream primal and fresh Tapenade parser, tangent,
and reverse outputs under strict fixed-form compilation. It then generates
FortAD JVP and VJP code for the port, compiles both modules, and runs a hand
Newton-map derivative, a central-difference check, and the adjoint identity.

```console
$ scripts/bench_tapenade_set01_lh086.sh
```

The pinned source and stored references remain under
`upstream/tapenade/nonRegressions/set01/lh086`.
