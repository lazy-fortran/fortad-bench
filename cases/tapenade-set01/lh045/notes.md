# Tapenade `nonRegressions/set01/lh045`

The pinned fixed-form source differentiates `S1(x,i1,y,i2,z)`. `S1` calls
`S2(7,x,8)` and `S3(6,y)`, with `/c1/` and `/c2/` COMMON state shared across
the calls. The stored tangent is strict-compilable. The stored reverse and
fresh reverse output are generated successfully but fail strict F2018
compilation because Tapenade emits the nonstandard `INTEGER*4 branch`.

FortAD refuses both exact probes at the `/c1/` COMMON declaration on line 34;
this is recorded as an exact-source boundary, not repaired upstream support.
The bounded port makes the initial `/c1/` value read by `S3` (`w4`) and the
initial `/c2/` value read by `S2` and `S3` (`v2`) explicit. It keeps the
original constants, branch, state update, and output values. FortAD's forward
transform compiles and is compared against the independent hand JVP in the
harness. Three bounded reverse transforms are generated, one per dependent,
but each fails strict compilation on FortAD's emitted `0.0_kind=8` literals.

`oracle.py` independently evaluates the closed-form JVP and VJP, checks both
branch paths against central differences, and checks the adjoint identity.
Run the complete bounded evidence probe with:

```sh
FORTAD_REPO=/var/tmp/fortad-lh035-pinned-xQjiZj \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh045/run.sh
```
