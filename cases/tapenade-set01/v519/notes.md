# Tapenade `todoF90/REFERENCES/v519`: standalone-program boundary

The pinned v519 source is a free-form `PROGRAM TEST_IT`.  It has no
subroutine or function interface: it writes one fixed character payload four
times, using list-directed output for the first two records and `A120` for the
last two, then stops.  The stored `program_p.f90` is Tapenade's parser
reference; `program_p.msg` is present, while stored tangent and reverse
references are absent.

The exact primal and stored parser reference both compile under strict
Fortran 2018 flags.  Fresh pinned Tapenade parser generation emits
`v519_p.f90`, which also compiles strictly.  Fresh tangent and reverse
generation emits only `v519_d.msg` and `v519_b.msg`; both report that the
`TEST_IT` root has no active input nor output.  No derivative source exists to
compile in those modes.

FortAD is probed against the exact upstream source in all three modes.  Its
parser request (`check --proc TEST_IT`) and its forward and reverse requests
all refuse with `no procedure named 'TEST_IT' in this source`, and none writes
an output file.  This is the precise no-procedure boundary, not an invalid
Fortran-source claim.

The independent Python oracle does not invoke a compiler, Tapenade, or
FortAD.  It models the source's four output records from the fixed field
sequence: the first two carry the 117-character payload, and the final two
carry that payload padded to 120 characters by `A120`.  It also checks that
the source has one standalone program unit and no callable procedure.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v519/run.sh
python3 cases/tapenade-set01/v519/test_contract.py
```

Generated files and compiler modules remain disposable under `/var/tmp`.
