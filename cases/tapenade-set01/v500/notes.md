# Tapenade `todoF90/REFERENCES/v500`: DATA and singular-output boundary

The pinned source is the free-form `nl_model_mie_orig(alpha_ext,PP)`
subroutine from the huneeus-lidar example.  Its exact primal and stored
reverse reference both compile with the repository's strict free-form flags.
The stored reverse reference only has implicit interfaces to Tapenade's tape
runtime, which is a compile warning rather than a source-compile failure.

Fresh Tapenade generation with the pinned executable produces parser, tangent,
and reverse files.  The fresh parser and tangent compile strictly.  The fresh
reverse source is rejected by strict compilation because this Tapenade output
uses nonstandard `INTEGER*4` for its branch variable; that is recorded as a
generation/compile boundary, not repaired.

FortAD's exact parser, forward, and reverse requests all stop at line 21,
the historical `DATA angle/120., 180./` statement, with `unsupported statement`
and no output file.  The case therefore has no FortAD derivative runtime claim.

The independent oracle is deliberately separate from both tools.  It models
the finite `alpha_ext` accumulation and checks its hand JVP with central
differences and its hand VJP with an adjoint identity.  It also checks the
exact loop semantics: `sigma_sca` remains zero while `PP` is normalized by it,
so the full exact output is not a finite numerical map.  No port is included;
changing the DATA handling or supplying a positive scattering accumulator
would define a different candidate.

Run the complete contract with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v500/run.sh
python3 cases/tapenade-set01/v500/test_contract.py
```

`result.txt` records the exact/stored compile statuses, fresh generated-file
hashes, exact FortAD refusals, the independent oracle, and pinned input hashes.
