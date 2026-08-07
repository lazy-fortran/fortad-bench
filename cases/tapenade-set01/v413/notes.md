# Tapenade `todoF90/REFERENCES/v413`: uninitialized local-state boundary

The pinned source contains only the free-form external function `f4(t,ss,hr)`:

```fortran
ss = hr ** (1./mt)
f4 = ss
```

`mt` is declared as a local double precision variable and is never assigned.
The exact source therefore has no defined numerical map: the exponent, `ss`,
and the function result all depend on an uninitialized value.  The strict
compiler accepts the source and emits the independent `-Wuninitialized`
diagnostic.  The stored `program_Rd.f90` also compiles strictly and emits the
same warning; its message records Tapenade's `DF03` warning that `mt` is used
before initialization.  There is no stored reverse reference in this corpus
directory.

Fresh pinned Tapenade parser, tangent, and reverse runs each generate a source
and message file.  All three fresh sources compile under the strict F2018 gate,
while retaining the uninitialized-`mt` warning.  The fresh outputs are evidence
of generation and source compilation only; they are not executable derivative
behavior because the primal itself has undefined local state.

FortAD is run on the exact unmodified source in parser, forward, and reverse
modes.  Each mode refuses before writing output with:

```text
fortad: unsupported statement at line 6
```

The independent oracle models the evaluation order directly: `mt` starts as an
undefined local, `1./mt` is undefined, and the subsequent power and assignments
remain undefined.  It therefore checks the reason no numerical port or finite-
difference/JVP/VJP claim is valid.  Initializing `mt`, exposing it as an input,
or selecting a bounded exponent would be a different candidate, so this case
deliberately contains no port or harness.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v413/run.sh
python3 cases/tapenade-set01/v413/test_contract.py
```

The compiler, fresh-generation, FortAD, independent semantic, and checksum
record is in [`result.txt`](result.txt).
