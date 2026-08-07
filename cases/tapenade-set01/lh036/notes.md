# Tapenade set01 `lh036`

`lh036` is an invalid-upstream fixed-form Fortran row.  The primal
`program.f` declares only the scalar function argument `t`, then assigns to
`ze(1,i,j)` and passes `ze` to `truc`/`truc1`.  There are no definitions or
interfaces for `ZE`, `TRUC`, or `TRUC1`, and `i` and `j` are used before they
are initialized.  The stored forward reference (`program_d.f`) and stored
parser output (`program_p.f`) preserve the same malformed interface pattern;
`program_d.msg` and `program_p.msg` are retained Tapenade diagnostics.

The exact primal and both stored Fortran references fail strict fixed-form
Fortran 2018 compilation.  Fresh pinned Tapenade parser, forward, and reverse
generation all return success, but strict compilation rejects the fresh parser
and tangent sources for the same `ZE(...)` function-result error.  The fresh
reverse source is syntax-compilable but still contains unresolved external
calls and cannot establish executable derivative semantics.

The exact pinned FortAD revision refuses both forward and reverse probes at
line 9.  There is no standard-conforming numerical port: defining the missing
procedures, changing `ZE` into an array, or choosing values for `i` and `j`
would change the candidate rather than test it.  The independent oracle is
therefore a compiler-behavior check that all three exact source files reject
the malformed `ZE(...)` usage.  This case is classified as
`expected-refusal-invalid-upstream`, not as a supported or runnable port.

Run from the repository root with an exact pinned FortAD checkout:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh036/run.sh
```

The runner builds only the local pinned FortAD checkout if its executable is
absent; it does not run the bench repository's project-wide `fo` pipeline.
The reproducible record is [`result.txt`](result.txt).
