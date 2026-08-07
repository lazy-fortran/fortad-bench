# Tapenade `nonRegressions/set01/lh090`

`lh090` is the fixed-form `testInitAdj` regression for a legacy backward
`GOTO` loop.  The exact routine computes `y=x*x`, updates `x=y*2`, and
branches back to label 100 whenever `y` is positive.  Thus every positive
initial `x` remains positive and follows the same branch forever.  No loop
bound, termination condition, root, or bounded numerical port is added.

The exact source and stored parser, tangent, and reverse files compile under
strict fixed-form F2018 checks.  The stored multidirectional file is the only
stored refusal because it includes the absent `DIFFSIZES.inc`.  Fresh pinned
Tapenade parser, forward, and reverse probes reproduce compiler-valid
artifacts.

At FortAD `7adc75030db3fa4422339d82d2725ae29ee13dac`, exact-source check,
forward, and reverse requests all refuse at line 11 with `unsupported
statement`; no output file is written.  This is the exact current behavior,
not a support claim.

`oracle.py` is independent of both differentiation engines.  It proves the
positive-input control-flow boundary, checks the tangent recurrence on finite
prefixes against central differences, and checks the corresponding reverse
dot-product identity.  The finite-prefix construction preserves the source
semantics without running its nonterminating positive-input path.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh090/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
