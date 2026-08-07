# Tranche P: `ht09`

`ht09` is a small, exact set03 Tapenade regression for an elementwise
`sqrt(abs(x))` map. The stored source is the upstream routine without a
semantic port, and the runner checks the upstream primal/reference sources,
fresh Tapenade parser/tangent/reverse generation, and strict compilation.

The same source is transformed by FortAD in both JVP and VJP modes. The
runtime harness compares both directions with an independently written
analytic derivative, sweeps central differences over several step sizes, and
checks the adjoint identity.

```console
$ scripts/bench_tapenade_set03_ht09.sh
```
