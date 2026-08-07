# Tapenade set01/ala00

This case retains the pinned exact source at
`upstream/tapenade/nonRegressions/set01/ala00`. The only differentiated
procedure is the unambiguous `root(x,y,initial)` subroutine. Its primal map
iterates `z = 2/(z+x)` until the source convergence test succeeds and then
assigns `y = z*x`; the enclosing program supplies `x=1` and `initial=24`.

The source and stored parser/tangent references pass both strict F2018 and
legacy fixed-form syntax gates. The stored reverse reference passes the
legacy gate but strict F2018 rejects its `REAL*8 cumul` declaration. Fresh
pinned Tapenade generation uses the explicit commands recorded in the
manifest: parser and tangent outputs pass both gates, while the reverse output
has the same strict `REAL*8` boundary.

FortAD is probed against the unchanged fixed-form source with `check`, forward,
and reverse requests. Each request reaches the exact `PRINT` at line 39 and
refuses with `unsupported statement at line 39`, without emitting a file. The
classification is therefore an expected FortAD refusal, not a repaired port.

`oracle.py` is deliberately independent of either AD implementation. It
checks the exact source shape, evaluates a separately implemented finite
fixed-point map, propagates a hand-written JVP, compares it with central
differences, and checks a separately propagated VJP using the dot-product
identity. It does not replace the source, execute generated Tapenade runtime
calls, or claim support for the `PRINT` statement or Tapenade's reverse stack.

Reproduce the full evidence with:

```sh
./cases/tapenade-set01/ala00/run.sh
python3 cases/tapenade-set01/ala00/test_contract.py -v
```

The runner accepts `TAPENADE_REPO`, `FORTAD_REPO`, and `FC` overrides while
still requiring the pinned revisions by default.
