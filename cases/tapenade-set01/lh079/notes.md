# Tapenade `nonRegressions/set01/lh079`: invalid exact-source boundary

The pinned directory contains the fixed-form primal `program.f`, stored parser,
forward, reverse, and multidirectional references, and one message file for
each reference.  The intended root is the double-precision function
`f(t,a,ad,b,bd,x)`.

The exact primal is not strict Fortran: gfortran rejects the `x**-0.5d0`
expression in line 6 (and the same spelling in line 8).  The source also reads
`xd` without declaring or initializing it.  These are source semantics, not a
missing FortAD option.  The stored parser, tangent, and reverse references
strictly compile with fixed-form Fortran 2018 flags, while the stored
multidirectional reference requires the absent upstream `DIFFSIZES.inc`.

Fresh pinned Tapenade parser, forward, and reverse probes all generate sources
and messages from the exact primal.  The generated files strictly compile;
their messages preserve the source's type-conversion and uninitialized-`xd`
diagnostics.  No multidirectional fresh probe is claimed because the upstream
dependency is absent from this row.

FortAD 7adc750 is run against the exact source in parser, forward, and reverse
modes.  The parser/check path accepts the terminal `RETURN` and writes its
check artifact.  Forward then refuses because `ad` is not declared in the
exact function interface, while reverse refuses because `f` is not declared
as a dependent.  Neither derivative request writes output.  This records the
current exact-source boundary, not a claim that repairing the source spelling
or declarations is supported.

`oracle.py` is independent of gfortran, Tapenade, and FortAD.  It inventories
the function and declarations, verifies that `xd` is read but undeclared, and
evaluates the source's arithmetic model with `xd` supplied explicitly.  The
model makes the unresolved input visible without pretending that the invalid
source has a standard-conforming runtime contract.  No synthetic root,
declaration repair, bounded port, or numerical derivative claim is introduced.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh079/run.sh
python3 cases/tapenade-set01/lh079/test_contract.py
```

Generated sources, compiler objects, and logs remain disposable under
`/var/tmp`; only this case directory is in scope.
