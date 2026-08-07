# `ala01` — `nonRegressions/set01/ala01`

The exact pinned source contains the program `test`, the selected procedure
`root(x,y,initial)`, and an unused `toto` helper. `root` iterates
`z <- sin(x*z*z)` until the fixed-point guard is satisfied and returns
`y = x*z`. The upstream `Options` file records Tapenade's `-context` mode.

The explicit fresh commands are:

```text
tapenade -p -context -root root -O . -o ala01 program.f
tapenade -d -context -root root -O . -o ala01 program.f
tapenade -b -context -root root -O . -o ala01 program.f
```

All three pinned Tapenade transformations succeed. The exact source and
stored tangent reference pass both strict F2018 fixed-form and legacy syntax
gates. The stored and fresh reverse references pass the legacy gate but are
rejected by strict F2018 because Tapenade emits `REAL*8 cumul`.

FortAD's exact `check`, forward, and reverse CLI probes all stop at the same
unsupported `PRINT` statement at line 39 and produce no output. This is an
expected refusal, not a repaired port. There is no external dependency
needed by the source; the blockers are the FortAD parser boundary and the
legacy declaration in Tapenade's reverse artifact.

`oracle.py` is independent of both AD engines. It implements the fixed-point
recurrence separately, checks a known primal result and iteration count,
compares its analytic JVP with central finite differences, and checks its VJP
with the dot-product identity.
