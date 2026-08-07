# Tapenade `todoF90/REFERENCES/v322`: legacy-kind and allocatable-state refusal

`v322` is a free-form historical failure component.  Its primal module
defines `SIMTEST1%qCalc` and `SOLVEREAL`, with derived-type allocatable
components and a large `SELECT CASE` over adsorption models.  The source
uses legacy `REAL*8` and `INTEGER*4` declarations throughout.  The directory
also contains `DIFFSIZES.f90`, the stored reverse reference, its message file,
the `-nolib` Options file, and a binary `simtest1.mod` artifact.

The strict F2018 compiler gate independently accepts `DIFFSIZES.f90` but
rejects both `program.f90` and `program_b.f90` at the nonstandard kind
declarations.  Under a legacy-kind probe the primal compiles; the stored
reverse then stops at the absent `ADMM_TAPENADE_INTERFACE` module.  This
distinguishes the source-language failure from the stored-reference
dependency failure without modifying any upstream file.

Fresh pinned Tapenade parser, tangent, and reverse runs use the recorded
`-nolib` option and `solvereal` root.  All three runs generate a source and a
message file, but each generated source fails the strict F2018 compiler gate
on the preserved `REAL*8` declarations.  Tapenade's reverse run also emits
its pointer/allocatable warning in the message stream; no executable
derivative behavior is claimed.

FortAD is run against the exact `program.f90` in parser, forward, and reverse
modes.  Each request refuses before writing output at the allocatable
component declaration on source line 6:

```text
fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 6; active allocation state is not represented yet
```

No bounded port is included.  Replacing `REAL*8`/`INTEGER*4`, inventing the
missing Tapenade runtime module, or exposing/specializing the allocatable
derived-type state would change the candidate.  The independent oracle is
therefore the reproducible strict compiler boundary, legacy dependency
diagnostic, pinned-source checksums, and FortAD's exact diagnostic/no-output
behavior rather than a fabricated derivative runtime.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v322/run.sh
python3 cases/tapenade-set01/v322/test_contract.py
```

The generated compiler, fresh-generation, exact-boundary, and checksum
record is in [`result.txt`](result.txt).
