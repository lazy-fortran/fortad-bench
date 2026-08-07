# Tapenade `todoF90/REFERENCES/v144`: invalid implicit-interface boundary

`v144` contains a free-form source file with the external array-valued
function `F` and the subroutine `head`.  `head` calls `F(a,2.0)`, although the
function's `u` dummy is declared rank one.  The array result is also used
through the caller's implicit interface.  The directory preserves Tapenade's
stored tangent and reverse outputs, but no parser reference.

The exact source fails the strict F2018 compiler gate.  gfortran reports that
an explicit interface is required for the array result and that the scalar
`2.0` mismatches rank-one `u`.  The stored tangent and reverse references also
fail strict compilation: the tangent reaches the generated `F_D` call with a
legacy real-array-index diagnostic, and the reverse reaches the analogous `F`
and `F_B` calls with the same legacy diagnostic and rank mismatch.

Fresh pinned Tapenade parser, tangent, and reverse generation all return
success and emit `v144_p.f90`, `v144_d.f90`, and `v144_b.f90`.  Each fresh
source fails the same strict compilation boundary; the generated `.msg` files
are present but empty at this pinned revision.

FortAD is probed on the exact `program.f90` with the parser, forward, and
reverse requests.  All three refuse at line 10 with `unsupported expression`
and emit no output file.  This is an exact-source capability boundary, not a
valid derivative result.

No bounded port is included.  Giving `F` an explicit interface or changing the
scalar actual into an array would repair or specialize an invalid program and
would not preserve an exact upstream behavior.  The independent oracle is the
strict compiler's reproducible diagnostic together with the pinned source and
fresh-generation checksums; no numerical oracle exists for a non-conforming
exact source.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v144/run.sh
python3 cases/tapenade-set01/v144/test_contract.py
```

The generated compiler, Tapenade, FortAD, and checksum record is in
[`result.txt`](result.txt).
