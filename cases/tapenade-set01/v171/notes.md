# Tapenade `nonRegressions/set05/v171`: module-only no-entry boundary

The exact row contains `program.f90`, Tapenade's stored parser rendering
`program_p.f90`, and an empty `program_p.msg`. The exact source is one free-
form `MODULE TEST` containing the default-initialized derived type
`DATATYPE`, integer module variable `m = 1`, and real parameter `o = 2`.
There is no `PROGRAM`, `SUBROUTINE`, `FUNCTION`, or `CONTAINS` statement.
The stored parser rendering preserves the module declarations and likewise
contains no callable unit.

Both exact files pass the pinned strict free-form compiler gate. The empty
stored message is recorded and hashed as an existing zero-byte reference.
Fresh pinned Tapenade probes run without a fabricated root: parser mode emits
`v171_p.f90` and its empty message, while tangent and reverse emit only
messages containing `No root unit to differentiate` and
`The code provided does not contain a top procedure`. The fresh parser
rendering also passes strict compilation.

FortAD is probed with the module name `test` only to obtain the reproducible
no-entry diagnostic. Its parser, forward, and reverse requests all refuse
with `no procedure named 'test' in this source` and write no output. This is
not evidence that `TEST` is a callable procedure; the independent oracle
checks the source shape, derived-type default, module initializations, and
empty callable/executable domain. No bounded port, harness, numeric JVP, or
VJP is claimed because there is no callable interface to preserve.

The sibling `todoC/REFERENCES/v171` directory is a separate C corpus row; its
files are not references for this Fortran `nonRegressions/set05/v171` case and
are intentionally not mixed into this case's source hashes.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v171/run.sh
python3 cases/tapenade-set01/v171/test_contract.py
```

Only this case directory is intended to be committed.
