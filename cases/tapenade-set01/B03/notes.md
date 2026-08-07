# Tapenade `nonRegressions/set01/B03`

`B03` contains one real fixed-form procedure, `viscflux`.  Its `Options` file
identifies `qpi2 fn vres6 qli1 qli2 qi1 qi2 qpi1` as active variables and
`fn vres6` as dependent variables.  The exact source and Tapenade's stored
parser, forward, and reverse references are used by path and hash; no source
copy, repair, or synthetic support port is present in this case.

The exact and stored sources pass the legacy fixed-form syntax gate but fail
the strict F2018 gate because they deliberately retain `INTEGER*4` and
`REAL*8`.  Fresh pinned Tapenade parser, forward, and reverse runs all
generate sources.  Those fresh sources have the same strict refusal and
legacy compile pass.  Tapenade's fresh messages preserve the upstream
diagnostics about the undeclared external `low` procedure and its missing
differential.

FortAD is probed three ways against the exact source: parser/check, forward,
and reverse, all with the explicit `viscflux` root.  Each refuses at the
`COMMON /files/` statement on source line 33 and emits no output.  This is an
expected exact-source boundary, not a forced port.

`oracle.py` independently inventories the exact procedure and checks the
final laminar tensor/heat-flux arithmetic block.  It hand-propagates a JVP,
checks it against central differences, and checks a separately hand-derived
VJP by the Jacobian-transpose dot-product identity.  The bounded model keeps
the unit normal and coefficients fixed; it does not implement COMMON, the
external `low` routine, or a runnable derivative source.

Run the complete pinned probe from the bench root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/B03/run.sh
python3 cases/tapenade-set01/B03/test_contract.py
```

The reproducible gate record is in [`result.txt`](result.txt).
