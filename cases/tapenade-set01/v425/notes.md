# Tapenade `todoF90/REFERENCES/v425`: module parser boundary

The pinned v425 source is a free-form module containing `addvector`.  The
subroutine declares nested `vector` and `rect` types, assigns the one defined
observable `c%w%x(1)`, and then evaluates `LEN(TRIM(fichier))` on a local
character variable that has not been initialized.  The stored tangent
reference is `program_Rd.f90`; there is no stored reverse reference.

The exact primal and stored tangent compile under strict Fortran 2018 flags.
Fresh pinned Tapenade parser, tangent, and reverse generation uses the
recorded `Options` setting (`-association byaddress`) and root `addvector`.
All three generated files also compile strictly.  The runner retains the
current CLI's generated filenames and diagnostics as disposable evidence.

FortAD's exact parser, forward, and reverse requests all refuse at the module
statement on line 1 with `unsupported statement`.  This is an exact-source
parser boundary, before FortAD reaches the derived-type activity.  Removing
the module wrapper or initializing `fichier` would change the exact case, so
no bounded port is claimed.

The independent Python oracle is deliberately a projection oracle, not a
runtime claim for the complete procedure: it models only the source-defined
assignment `c%w%x(1) = a%w%x(1) + b%w%x(2)`.  It checks hand JVP/VJP values,
central differences, and the adjoint identity while documenting the excluded
uninitialized-local path.

Run the complete probe from the repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v425/run.sh
python3 cases/tapenade-set01/v425/test_contract.py
```

The compiler, fresh Tapenade, FortAD refusal, independent-oracle, and source
checksum record is in [`result.txt`](result.txt).
