# Tapenade `todoF90/REFERENCES/v385`: MPI polling and allocatable boundary

`v385` contains the free-form subroutine `fonctiontTest(buf,resultat)`.  It
allocates both arrays, fills `buf` with `1..10`, sends it with `MPI_ISEND`,
polls the request with `MPI_TEST`, and squares the entries after the poll.
The exact source and both stored derivatives use nonstandard `REAL*8`, so the
strict F2018 `mpifort` gate rejects all three before the MPI interface can be
validated.  The pinned Tapenade executable nevertheless generates parser,
forward, and reverse files, reporting the seven-actual `MPI_ISEND` call and
the unexpected `MPI_TEST` primitive; all fresh files fail the same strict
`REAL*8` gate.

FortAD's exact parser, forward, and reverse modes all stop at the allocatable
declaration/component boundary and produce no output.  This is recorded as an
expected refusal, not repaired.  `oracle.py` is an independent check of the
local square-map tangent and reverse dot-product identity after a hypothetical
successful MPI poll.  It is a semantic diagnostic for the arithmetic only,
not an MPI port or a claim that the upstream routine is executable.

Run the complete case evidence with:

```sh
cases/tapenade-set01/v385/run.sh
python3 cases/tapenade-set01/v385/test_contract.py
```

The runner keeps generated sources, compiler modules, logs, and FortAD output
in a disposable `/var/tmp` directory and commits only this case's contract
and result record.
