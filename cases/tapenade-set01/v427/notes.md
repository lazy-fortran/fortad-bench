# Tapenade `todoF90/REFERENCES/v427`: allocatable module-state boundary

The pinned free-form source defines module `m` with two allocatable arrays and
the subroutine `setupData(dim)`.  It deallocates `someTData` when necessary,
then allocates both `someTData(dim)` and `i(dim)`.  The procedure assigns no
array elements and returns no numeric value.  A first call with a
nonnegative extent therefore establishes only allocation state.  A later
call deallocates and reallocates `someTData`, but attempts to allocate `i`
again without deallocating it, which is a runtime allocation failure.

The exact primal and stored `program_Rd.f90` reference both compile under the
strict F2018 gate.  The historical `m.mod`, `Options`, and message file are
retained as exact upstream evidence; no derivative source for the parser or
reverse alternatives is stored.

Fresh pinned Tapenade parser generation emits `v427_p.f90` and its message,
and the generated parser source compiles strictly.  Tangent and reverse
generation each emits only a message containing `AD06`: the root has no
active input or output, so no derivative source is applicable.  The old
`-association byaddress` option is passed as recorded by the corpus; this
Tapenade executable reports it as an unrecognized file argument while still
completing generation.

FortAD is run on the exact unmodified source in parser, forward, and reverse
modes.  Every mode refuses before writing output at line 2, the first
allocatable declaration/component.  The independent oracle models the
allocation transitions and the repeated allocation failure without invoking
any compiler, Tapenade output, or FortAD output.  Since this candidate has no
numeric result and active allocation lifetime is unsupported, no bounded port
or derivative numerical claim is made.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v427/run.sh
python3 cases/tapenade-set01/v427/test_contract.py
```

`result.txt` records strict compiler statuses, fresh Tapenade generation and
strict compilation where a source exists, exact FortAD refusals, the
independent semantic oracle, and hashes for every pinned v427 reference.
