# Tapenade `todoF90/REFERENCES/v402`: invalid allocation-state source

`v402` contains the free-form primal `program.f90`, a stored reverse source,
and its message file.  The main program calls `TimeLoop()` with zero actual
arguments even though `TimeLoop(k)` declares one dummy argument.  The primal
also uses legacy `REAL*8` declarations.  The stored reverse source imports
`DIFFSIZES`, but that module is absent from this corpus directory.

The exact strict compiler contract therefore records two independent
refusals: `program.f90` fails at the nonstandard kind declaration (and its
subsequent invalid allocation state), while `program_b.f90` fails immediately
because `diffsizes.mod` is unavailable.  No stored parser or tangent source
is present.

Fresh pinned Tapenade parser, tangent, and reverse runs all generate their
`v402_p.f90`, `v402_d.f90`, and `v402_b.f90` outputs and message files.  Each
generated source preserves `REAL*8` and fails the strict F2018 compiler gate.
The generation diagnostics also preserve Tapenade's conflicting-argument
warning for the zero-actual `timeloop` call.

FortAD's exact parser, forward, and reverse requests all refuse before writing
an output file at the allocatable declaration on line 12:

```text
fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 12; active allocation state is not represented yet
```

There is no bounded port.  Fixing the call arity, replacing `REAL*8`, or
supplying `DIFFSIZES` changes the candidate; the invalid source has no
standard-conforming numerical map whose derivative could be checked.  The
independent oracle instead checks the source-level call-arity and missing
module obligations without comparing generated files to the patch.

Run the complete probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v402/run.sh
python3 cases/tapenade-set01/v402/test_contract.py
```

The compiler, fresh-generation, exact FortAD boundary, oracle, and checksum
record is in [`result.txt`](result.txt).
