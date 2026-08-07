# Tapenade `todoF90/REFERENCES/v414`: derived-type output boundary

The pinned source defines module `example3`, with a private `vector` type and
the function `addvector(a,b)`.  The function assigns only `addvector%x`; its
`y` component is intentionally not assigned in the corpus source.  The stored
`program_Rd.f90` is the association-by-address tangent reference and compiles
strictly, with only an unused-variable warning.

Fresh pinned Tapenade generation with `-association byaddress` and root
`addvector` produces parser, forward, and reverse files.  All three generated
files compile strictly.  Their generated module contains its own private
vector and differentiated vector types, and the derivative operates on the
defined `x` component only.

FortAD's exact parser, forward, and reverse commands all return success and
write files, but strict compilation refuses each file.  The parser output has
an empty `result()` and lacks the source module's `VECTOR` declaration.  The
forward output has a blank derivative dummy in its generated signature and
also lacks `VECTOR`; the reverse output emits `TYPE(VECTOR) :: addvector%x_b`,
which is not a valid declaration.  These are reproducible code-generation
boundaries, not claims that the exact source is invalid.

The independent oracle deliberately checks only the defined observable
`addvector%x = a%x + b%x`: a central-difference JVP sweep and the scalar
forward/reverse adjoint identity both pass.  It does not assign a value to
`y`, does not repair the private type context, and does not claim a bounded
port or support for the incomplete object result.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v414/run.sh
python3 cases/tapenade-set01/v414/test_contract.py
```

The compiler, fresh Tapenade, FortAD, independent-oracle, and checksum record
is in `result.txt`.
