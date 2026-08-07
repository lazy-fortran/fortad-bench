# Tapenade `todoF90/REFERENCES/v02`

The selected entry point is the free-form module procedure
`modu.top(i1,i3,o1,o2,o3)`.  The module variable `i2` is hidden mutable state.
`top` overwrites `i1`, conditionally overwrites `i3`, calls `sub1`, then
overwrites the module state with `5.0`; `o2` and the final `o3` are constants.
The `sub1` branch is retained, including the `i1 > 3.0` path and the
`i1 <= 3.0` path.

The exact `program.f90` and stored `program_b.f90` compile under the strict
free-form gate.  Fresh pinned Tapenade 3.16 generation with the corpus
`-nooptim spareinit` option produces parser, tangent, and reverse files.
The fresh parser and tangent compile strictly; fresh reverse fails the strict
F2018 gate because Tapenade emits nonstandard `INTEGER*4` declarations.

FortAD `check` returns a procedure-only output that fails strict compilation
because its generated `g` and `i2` uses are undeclared.  Exact forward mode
also returns status zero but its generated module fails strict compilation on
the undeclared module state `i2`; exact reverse refuses with
`assignment to undeclared 'g'`.  These are exact-source boundaries, not
support claims.

The bounded `port.f90` makes the hidden incoming state explicit as `i2_in`
and preserves the observable `top` semantics in a standard-conforming
interface.  It leaves `i3` as `intent(inout)` because the original negative
branch changes it.  It is deliberately a specialization of this one module
entry point; it does not claim to repair or support the original hidden-state
interface.  FortAD-generated bounded forward and reverse procedures are
compiled and exercised by `harness.f90`.  `hand.f90` supplies an independent
closed-form JVP, while `oracle.py` checks that formula against central
differences on both outer and inner branch regions and verifies the adjoint
identity.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v02/run.sh
```
