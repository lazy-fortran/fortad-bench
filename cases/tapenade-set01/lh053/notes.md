# Tapenade set01 `lh053`

`lh053` is a legacy fixed-form routine whose exact source uses `REAL*8`,
labeled/shared `DO` termination, COMMON state, EQUIVALENCE, and an external
`BINAIR` function that is not supplied in this row.  Strict Fortran 2018
compilation therefore rejects the exact source and every stored derivative;
the `program_dv.f` reference also requires the absent `DIFFSIZES.inc` include.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds for the
real root `cg12v4`, but all three fresh outputs fail the same strict compiler
gate.  The stored derivatives are recorded as provenance only and are not used
as fresh-generation evidence.

Pinned FortAD refuses both exact modes at the labeled DO construct on line 13.
For a bounded numerical probe, `port.f90` makes the COMMON values `NC` and
`RCAL` explicit, converts the control flow to structured `DO` loops, and keeps
the missing `BINAIR` algebra explicitly.  This is intentionally not a
repair of the upstream row or a claim of exact support.  FortAD transforms the
bounded port in forward mode; its reverse transform refuses the in-place `g`
loop because per-iteration storage is required.

The forward product is checked against an independent Python hand chain-rule
implementation, a central-difference sweep, and an adjoint identity.  The
compiled harness checks the generated JVP against the independent expected
values.  Run the reproducible case with:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh053/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
