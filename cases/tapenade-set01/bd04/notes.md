# Tapenade `nonRegressions/set01/bd04`

`program.f` is the exact fixed-form upstream source.  Its main program calls
`toto(a)` with a `1000` by `1000` array.  `toto` evaluates both DO-loop
controls before entering the loop, then assigns new values to the control
variables inside the bodies, prints each `(i1,i2)` pair, and doubles the
selected array element.  The source is kept in the pinned Tapenade checkout;
this case does not copy, repair, or port it.

The unmodified source and the checked-in Tapenade parser, tangent, and reverse
references pass strict fixed-form syntax compilation.  Fresh generation from
the pinned Tapenade checkout also succeeds for `-p`, `-d -root toto`, and
`-b -root toto`, and each fresh output compiles strictly.

At FortAD `72ca2aa1c6c7d4b171b13a3e13c5190944080032`, exact `check`, forward,
and reverse attempts all refuse at source line 26 with
`fortad: unsupported statement at line 26`; no output file is emitted.  This
is an expected exact-source boundary caused by the upstream `PRINT` statement,
not a claim that the source is invalid or that a port is available.

`oracle.py` is an independent behavioral oracle.  It models Fortran DO-loop
control evaluation, verifies the 100-entry trace and selected-cell update, and
checks the induced JVP by central difference plus the VJP adjoint identity.
It does not use Tapenade or FortAD output and does not create a repaired
Fortran implementation.

Run the complete gate with:

```console
FORTAD_REPO=/path/to/a/clean/checkout-at-72ca2aa \
  cases/tapenade-set01/bd04/run.sh
python3 cases/tapenade-set01/bd04/test_contract.py
```

The run record, including the explicit refusals, is in [`result.txt`](result.txt).
