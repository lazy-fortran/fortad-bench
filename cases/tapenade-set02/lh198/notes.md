# Tapenade set02 `lh198`

`lh198` is a pure fixed-form Fortran regression for COMMON-block zone
numbering.  `AAA`, `BBB`, and `CCC` use `/comF/` and `/comG/`; the internal
`DDD` procedure declares the same `/comG/` storage as `v5,v6`, while `BBB`
sets the second slot through `v4`.  The exact primal is compiler-valid and
prints `x=1.5` and `y=15`.

The exact primal and stored parser, tangent, and reverse references pass both
strict F2018 and legacy fixed-form syntax gates.  Fresh pinned Tapenade
parser, tangent, and reverse products generated from `program.f` also pass
both gates.  This is source/compiler evidence, not a FortAD support claim.

Current FortAD parses and re-emits the selected `top(x,y)` procedure, but its
exact forward and reverse transforms deliberately refuse at the active `AAA`
call because no derivative rule is registered.  Neither transform emits a
derivative file.  The case is therefore an expected FortAD refusal, not an
invalid upstream closure; no repaired source is included.

The independent Python oracle models the exact shared-storage dataflow and
checks primal values, a JVP, central differences, and the VJP dot-product
identity.  It is a behavioral measurement of the upstream semantics, not a
replacement source for FortAD.

Run from the bench root with the pinned checkouts, for example:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set02/lh198/run.sh
```
