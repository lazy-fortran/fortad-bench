# Tapenade set01 `lh054`

`lh054` is a small fixed-form subroutine whose only numerical effect is the
in-place update `b(1)=2*b(1)`.  Its legacy interface has an unused alternate
return and implicit dummy declarations.  The exact source, stored parser,
tangent, and reverse references compile with the recorded strict fixed-form
flags.  The stored multidirectional reference is the one exception: it
requires `DIFFSIZES.inc`, which is not present in this upstream row.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds with
`-p`, `-d -root test`, and `-b -root test`; all three generated files compile
strictly.  This is fresh-generation evidence, not a claim that the historical
stored derivatives are complete.

Pinned FortAD accepts the exact transform requests, but the generated forward
source omits declarations and the generated reverse source repeats `b_b` in
its formal argument list.  Both exact outputs therefore fail strict
compilation.  That is a FortAD semantic/code-generation mismatch, not a
successful exact-support result.

`port.f90` is a bounded standard-conforming probe.  It keeps the original
dummy arguments with explicit types and intents, removes only the unused
alternate return, and preserves the observable update.  FortAD's bounded
forward output compiles and runs in `harness.f90`; its bounded reverse output
still fails strict compilation because of the duplicate `b_b` argument.
`oracle.py` independently checks the hand JVP/VJP, a central-difference sweep,
and the adjoint identity.  Run the complete gate with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh054/run.sh
```

The complete pinned gate record is in [`result.txt`](result.txt).
