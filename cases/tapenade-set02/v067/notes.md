# Tapenade `nonRegressions/set02/v067`

`v067` is a valid pinned fixed-form Fortran source, not an invalid-upstream
case.  `program.f` contains `ADJ_FCN(T,Y,YP,RESULT,RP)` and the exact dataflow
`t = y + pi`.  The exact file has CR-only line terminators; that byte-level
source is preserved and is the only source passed to the exact engine probes.

Both `program.f` and the stored `program_p.f` compile with strict F2018
fixed-form flags and with the legacy compiler control.  Fresh Tapenade probes
on the exact `program.f` return successfully but report `unit ADJ_FCN: not
found`; no parser, tangent, or reverse source is emitted.  This is recorded as
a precise Tapenade input boundary.  The stored `program_p.f` is retained and
hashed as reference evidence; generating from it would not establish exact
`program.f` support.

FortAD's exact parser emits a compilable normalized source.  Its exact forward
probe emits a compilable but empty derivative stub, and its exact reverse probe
emits no source with `assignment to undeclared 't'`.  Neither result is a valid
exact derivative transform, so no repaired or transformed port is claimed.

The independent oracle checks the pinned bytes and the mathematical source
semantics directly: the analytical JVP and VJP are both one, central
differences converge to one, and the scalar adjoint identity holds.  It does
not consume Tapenade or FortAD output.

Run the complete evidence probe with:

```bash
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set02/v067/run.sh
```
