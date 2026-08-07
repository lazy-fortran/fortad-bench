# Tapenade `todoF90/REFERENCES/bd01`

`bd01` contains a small two-file module-call example.  `program.f90` defines
`TITI(a,b,c)`, imports module `TATA`, and calls `TOTO(a,b,c)`; `tata.f90`
defines that module procedure with the exact update `a = b*c`.  The checked-in
`Options` line is retained as corpus evidence even though its historical head
name `det` is not declared by these two source files.

The unmodified files compile with strict F2018 free-form flags when GCC's tab
diagnostic is explicitly left as a warning.  This matters because the source
uses leading tabs, which `-pedantic-errors` otherwise promotes to an error;
the warning is recorded rather than rewriting the upstream source.  Fresh
Tapenade parser, tangent, and reverse generation from the pinned checkout
also succeeds, and all three generated files compile strictly.

FortAD's parser round-trip accepts both source files.  Its exact forward and
reverse transforms for the standalone module procedure `TOTO` generate and
compile.  The exact transforms for the caller `TITI` refuse at the external
module call with, respectively, `no derivative rule for the call to 'TOTO'`
and `no reverse rule for the call to 'TOTO'`; no exact caller derivative is
claimed.

The bounded `port.f90` is deliberately narrow: it exposes one single-file
routine with the same `a=b*c` update.  Its hand JVP/VJP, central differences,
adjoint identity, and compiled FortAD forward/reverse harness are independent
behavioral checks for that specialization only.  They do not repair the
corpus source or turn FortAD's exact two-file call refusal into support.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/bd01/run.sh
```

The generated strict-compile, fresh-generation, exact-boundary, bounded
runtime, oracle, and source-checksum record is in [`result.txt`](result.txt).
