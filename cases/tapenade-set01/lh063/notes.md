# Tapenade `nonRegressions/set01/lh063`

`lh063` is a fixed-form duplicate-definition regression rooted at `f(t)`.  The
exact `program.f` translation unit contains two complete, identical global
definitions of `f`; strict `gfortran` rejects the second definition.  The
stored parser, tangent, and reverse references are isolated single-procedure
artifacts and compile strictly.  The stored multidirectional reference is the
one additional refusal because it includes the absent `DIFFSIZES.inc`.

Fresh pinned Tapenade generation succeeds for `-p`, `-d -root f`, and
`-b -root f`.  Tapenade emits one normalized definition for the parser output,
and fresh parser, tangent, and reverse outputs all compile strictly.  This is
fresh-generation evidence, not evidence that the duplicate exact upstream
translation unit is valid.

FortAD is run on the unmodified exact source in forward and reverse modes with
`t` independent and `f` dependent.  Both requests refuse before emission at
the `RETURN` statement on line 5 and leave no generated file.  That diagnostic
is a separate FortAD parser boundary; the case classification is driven by the
duplicate global definition already rejected by the independent compiler.

No bounded numerical port is included.  Removing either duplicate definition
would repair the invalid upstream translation unit, even though the two bodies
are textually identical, and would no longer be an exact-source support claim.
The independent case-local oracle therefore checks the compiler acceptance and
refusal behavior of every exact and stored source instead of assigning
derivatives to a repaired program.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh063/run.sh
```

The complete pinned gate record is in [`result.txt`](result.txt).
