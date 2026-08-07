# Tapenade `nonRegressions/set01/lh089`

`lh089` is the fixed-form `pushpop` regression.  The exact routine pushes
`a`, performs the in-place updates `a=a*b` and `b=b+a`, restores `a`, and
finishes with `b=a/b`.  The external `PUSHREAL8` and `POPREAL8` procedures
operate on the hidden `/adstack/`; their Tapenade summary is supplied by the
upstream `PUSHPOPGeneralLib` selected by `Options`.

The exact primal and stored tangent reference use legacy `REAL*8`.  They
therefore fail the strict pedantic F2018 compiler gate at the declaration but
compile under legacy fixed-form flags.  Fresh pinned Tapenade parser, forward,
and reverse probes all generate sources; each has the same strict `REAL*8`
refusal and compiles under the legacy gate.  The external summary is checked
before running those probes, so a missing dependency cannot be mistaken for a
transformation result.

FortAD at `7adc75030db3fa4422339d82d2725ae29ee13dac` parses the exact
procedure with `check` and emits a round-trip source.  That output omits the
legacy dummy declaration, as exposed by the independent compiler check.
Exact forward mode then refuses `a` as undeclared; exact reverse mode refuses
dependent `a` for the same declaration-resolution boundary.  Both refusals
write no derivative file.  The case does not replace `REAL*8`, add `INTENT`,
register an invented differential rule, or claim a bounded Fortran port.

`oracle.py` is independent of Tapenade and FortAD.  It inventories the exact
operation order, models the push/pop state transition, checks the resulting
analytic JVP against central differences, and checks the reverse dot-product
identity.  `test_contract.py` contains exactly three behavioral contracts:
that independent semantic oracle, fresh Tapenade generation plus compilation,
and direct exact-source FortAD behavior.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh089/run.sh
python3 cases/tapenade-set01/lh089/test_contract.py
```

Generated files, objects, and logs remain in disposable temporary
directories; only this case directory is in scope.
