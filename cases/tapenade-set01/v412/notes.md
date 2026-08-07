# Tapenade `todoF90/REFERENCES/v412`

This historical source combines double-precision helpers `f0` through `f5`
with single-precision `f6` and `f7`, called from `top(x,y)` with a
double-precision actual.  `f5` also calls `undef` without a declaration.
The exact source consequently fails the strict F2018 compiler gate through
implicit-interface return-type and argument-kind mismatches.

The only stored derivative is `program_Rd.f90`; it is preserved as an
expected strict-compilation refusal because its generated function results
are not declared consistently.  Pinned Tapenade generates parser, forward,
and reverse files, but each fresh file fails strict compilation at the same
mixed-kind boundary.

FortAD refuses all three exact modes before writing a file, reporting
`unsupported statement at line 56`, the `RETURN` statement in `top`.  There
is no bounded port: repairing the source's kind/interface defects or
replacing the unsupported statement would no longer test the exact corpus
case.  The complete evidence is in [`result.txt`](result.txt).
