# Tapenade `todoF90/REFERENCES/v377`: MPI interface and communication refusal

`v377` contains a free-form MPI program with the procedure `test(ce,rank)`,
its stored tangent and reverse references, and two stored driver files.  The
source imports the explicit `mpi` module but calls `MPI_SEND` with both the
status array and `ierr` after the communicator.  The installed MPI interface
therefore rejects the exact primal with eight actual arguments where seven are
expected.  The stored `program_d.f90`, `program_b.f90`, `topd.f90`, and `topb.f90`
compile strictly because their Tapenade MPI calls are external through the
ADFirstAidKit support module or implicit interfaces.

Fresh pinned Tapenade generation succeeds for `-p -root test`, `-d -root
test`, and `-b -root test`.  The fresh parser source reproduces the exact
`MPI_SEND` interface failure.  The fresh tangent and reverse sources compile
strictly when the pinned `ADFirstAidKit/adMPI.f90` module is compiled first;
their MPI derivative calls intentionally remain external and are not linked or
executed here.  This separates generated-source compilation from runtime MPI
support.

FortAD's exact parser mode emits a procedure-only file, which fails the same
strict MPI interface check.  Exact forward mode refuses at `MPI_irecv` because
there is no derivative rule for that call.  Exact reverse mode refuses at a
loop whose results do not leave the body.  These are engine boundaries after
the independent compiler boundary, not claims that the invalid source is
supported.

The independent oracle is a small Python model of the source's visible MPI
rank obligations.  With the minimum advertised world size of three, `main`
calls `test` only on ranks 0 and 1: rank 0 receives from invalid rank `-1`, and
rank 1 sends to rank 2 even though rank 2 does not enter `test`.  Thus no
standard-conforming communication behavior exists to differentiate.  No
bounded port is included: fixing the argument list, adding the missing
communication, or replacing MPI with a local array operation would be a new
program.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v377/run.sh
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
  python3 cases/tapenade-set01/v377/test_contract.py
```

The compiler, generated-source, FortAD, oracle, and checksum record is in
[`result.txt`](result.txt).
