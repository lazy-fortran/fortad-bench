# Tapenade `nonRegressions/set01/ala03`: MPI wave/checkpoint boundary

`ala03` is retained as the exact pinned fixed-form MPI/checkpointing source.
Its selected Tapenade head is `wave_resolution(u_global)/(c)`, as recorded by
the upstream `Options` file. The source calls `update` and `collect`, uses
`mpif.h`, and marks manual `NOCHECKPOINT` and `CHECKPOINT-START/END` regions.
No source copy, MPI stub, interface repair, or bounded Fortran port is added to
this case.

Fresh pinned Tapenade parser, forward, and reverse commands all return zero
and emit `ala03_p.f`, `ala03_d.f`, and `ala03_b.f` plus message files. The
runner expands the upstream head and `-noisize` options and supplies the
available pinned `ADFirstAidKit` include and host MPI `mpif.h` include. This
resolves external headers for the probe without altering the exact source.
The fresh parser preserves the source's MPI argument-mismatch boundary under
strict F2018; fresh forward compiles strictly; fresh reverse preserves
Tapenade's strict `INTEGER*4` refusal. All three fresh artifacts pass the
legacy fixed-form syntax gate. The stored forward and reverse references show
the same respective boundaries.

FortAD's exact `check` mode succeeds and writes its procedure-only output.
Exact forward and reverse requests refuse at the external `update` call
because the current FortAD has no registered derivative or reverse rule for
that call; neither derivative output is created. This is recorded as an
expected refusal, not as a claim that MPI or Tapenade runtime support exists.

`oracle.py` is independent of both AD engines. It models the closed serial
(`p=1`) arithmetic of `update`: the exact sinusoidal initial/boundary data,
the first-step and later-step wave recurrences, and their hand-propagated
directional and reverse sensitivities. It checks a primal result, a JVP
against central differences, and the VJP dot-product identity. It does not
execute the MPI source or turn the serial model into a repaired candidate.

Reproduce the evidence from the bench root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/ala03/run.sh
python3 cases/tapenade-set01/ala03/test_contract.py -v
```

The runner writes the complete status, diagnostic, source hash, generated
artifact hash, and case-artifact hash record to `result.txt`.
