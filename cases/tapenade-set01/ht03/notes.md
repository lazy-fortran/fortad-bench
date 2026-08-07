# Tapenade `nonRegressions/set01/ht03`

`ht03` is a fixed-form two-subroutine regression.  `top` first computes
`o3=i3*i2`, calls `sub1`, and then multiplies the two values returned through
`o1` and `o2`.  `sub1` overwrites `i2`, opens the external file `toto`, reads
`o2` from unit 3, and computes `o1=i1/o2`.

The pinned upstream row contains the exact `program.f` and Tapenade's stored
reverse reference `program_b.f`/`program_b.msg`.  Both sources pass strict
F2018 and legacy fixed-form syntax gates.  Fresh pinned Tapenade parser,
forward, and reverse runs also generate sources that pass both compiler gates.
The stored message records the I/O state needed around the `sub1` call and the
useful value read from unit 3.

FortAD's exact check parses and re-emits the source; its re-emitted free-form
source passes strict and legacy syntax gates.  Differentiating `top` refuses
at the active call to `sub1` because no derivative/reverse call rule is
registered.  Differentiating `sub1` directly reaches the exact I/O boundary
and refuses `OPEN` at line 17.  All refusal probes emit no derivative file.

`oracle.py` is independent of both differentiation engines.  It verifies the
source shape, models the arithmetic map while treating the external read as a
fixed environmental value, compares its hand JVP with central differences,
and checks the hand VJP through the Jacobian-transpose dot-product identity.
That conditional model is an oracle only; no external file behavior is
implemented and no repaired port is claimed.

Run the complete evidence probe from the bench root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/ht03/run.sh
```

The reproducible gate record is in [`result.txt`](result.txt).
