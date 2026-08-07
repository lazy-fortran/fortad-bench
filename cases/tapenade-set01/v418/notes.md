# Tapenade `todoF90/REFERENCES/v418`: MPI interface and stored-driver boundary

`v418` contains the free-form MPI ring program `anneau`, with two communication
subroutines.  Rank zero uses `msg1`, which posts a nonblocking send and receive
before waiting; all other ranks use `msg2`, which receives and then sends.  The
stored tangent is `program_Rd.f90`, and `topd.f90` is its stored MPI driver.

The exact primal is intentionally retained unchanged.  Strict `mpifort`
rejects `program.f90` because `msg2` passes both the `statut` array and `code`
to `MPI_SEND`: the explicit MPI interface expects seven actual arguments, not
eight, and reports the status rank mismatch.  The stored tangent source itself
compiles strictly using implicit interfaces for its `TLS_MPI_*` calls.  Its
stored driver remains invalid: `topd.f90` uses `real4rdtype` without declaring
it under `implicit none`, after `program_Rd.f90` supplies the `AATYPES` module.
The empty historical `program_Rd.msg`, `Options`, `mpif.h`, and `rund` are
preserved as upstream evidence through hashes rather than copied into the case.

Fresh pinned Tapenade generation uses the retained association-by-address
option and roots `msg1` and `msg2`.  Parser output is generated but fails the
same strict MPI interface check.  Tangent and reverse output is generated and
compiles strictly when the pinned `ADFirstAidKit/adMPI.f90` support module is
compiled first.  This is generation/compilation evidence, not an execution or
derivative-support claim for the invalid MPI program.

FortAD's exact parser mode emits each selected procedure.  The `msg1` parser
output compiles strictly; the `msg2` parser output preserves the `MPI_SEND`
interface error.  Exact forward and reverse requests refuse before writing an
output: `msg1` stops at `MPI_ISEND`, and `msg2` stops at `MPI_RECV`, because no
MPI derivative rules are registered.

The independent `oracle.py` models only the intended payload permutation for a
world of at least two ranks: rank `r` receives the payload from `(r-1) mod n`.
It checks the numerical map over world sizes two through eight, a central-
difference JVP, and the matching VJP adjoint identity.  It does not repair the
MPI calls, declare `real4rdtype`, invoke a compiler, or claim a bounded port.

Run the complete probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v418/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v418/test_contract.py
```

`result.txt` records the exact/stored compiler statuses, fresh generated
source hashes, both FortAD roots and modes, the independent oracle, and the
hashes of every pinned v418 reference.
