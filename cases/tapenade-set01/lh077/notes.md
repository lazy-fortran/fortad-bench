# Tapenade `nonRegressions/set01/lh077`

The selected entry point is the fixed-form `testinit(A,B,C)` routine; its
helper `toto(T,S,R)` is also recorded because it is the call boundary that
FortAD diagnoses.  `testinit` initializes `L1(i) = 1/i` with integer operands,
so `L1(1)=1` and `L1(2:100)=0`.  It then performs two ordered `toto` updates:

`C <- (C + sum(L1**2))*B`, followed by `C <- (C + sum(A**2))*8.5`.

The exact primal, stored parser, tangent, and reverse references compile under
the strict fixed-form gate.  The stored multidirectional reference fails only
because `DIFFSIZES.inc` is absent.  Fresh pinned Tapenade parser, tangent, and
reverse generation succeeds and each fresh output compiles strictly.

FortAD refuses exact forward and reverse transformation at the `toto` call:
the legacy callee has no `INTENT` declarations and may write actual arguments,
so the call requires plain writable variables.  This is classified as an
expected exact-source refusal.

The bounded `port.f90` makes the output `c_out` explicit and preserves the
integer-division initialization and the two-stage real-valued function.  It
uses the algebraically equivalent closed form `8.5*((c+1)*b+sum(a*a))` so
FortAD can reverse the reduction; this is a bounded mathematical-semantics
port, not a claim of bitwise equivalence to the legacy loop accumulation.
The literal `8.5` is retained.  `hand.f90` supplies independent JVP and VJP formulas;
`oracle.py` checks those formulas by central differences and an adjoint
identity.  The compiled harness compares the port, hand implementation, and
FortAD's generated forward and reverse procedures.  This bounded evidence is
not an exact-source support claim.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh077/run.sh
```
