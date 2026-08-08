# Tapenade `examples/big01/B04`

`B04` is available exactly at the pinned Tapenade checkout and remains
unmodified. The fixed-form source has a local include closure, but it is not a
valid compiler input: strict F2018 rejects deleted legacy constructs and both
strict and legacy gates report two main programs. The legacy gate also reports
nonconforming tabs under the recorded `-pedantic-errors` controls.

The stored `program_p.f` reference contains `SUBROUTINE _MAIN_()` and a second
`PROGRAM MOGAUT`; stored `program_d.f` and `program_dv.f` additionally include
`DIFFSIZES.inc`, which is absent from the exact B04 directory. These references
are hashed evidence only. No include, source repair, or generated product is
copied into the case.

Fresh Tapenade 3.16 at the pinned revision generates parser, tangent, and
reverse products and messages for `MOFDER_GEAR`. The fresh parser fails the
fixed-form compiler gate on `_MAIN_`/two main programs, the tangent compiles,
and reverse cannot compile without `DIFFSIZES.inc`. FortAD's exact parser,
forward, and reverse requests all stop at the malformed token on source line
20599 and emit no output.

This is classified `unsupported-invalid-upstream-fortran`. It is not a support
claim and therefore has no derivative oracle. Run the complete evidence probe
with:

```bash
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-big01-B04/run.sh
```
