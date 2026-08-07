# Tapenade `todoF90/REFERENCES/v503`: incomplete `SYSTEME` boundary

`v503` contains only `program.f90`, a 427-line free-form `program SYSTEME`.
The pinned upstream directory has no `Options` file and no stored tangent,
reverse, or message reference.  Those absences are part of the case and are
not repaired or represented by generated files committed here.

The exact source is not a strict, self-contained Fortran program.  Its first
allocation, `allocate (SVRAI(size(X)), STAT = retour)`, reaches line 80, but
`SVRAI` and the other allocation targets have no declarations.  The later
`SELECT CASE` also relies on undeclared project constants and includes
external project calls with no interfaces.  Strict compilation therefore
records an expected refusal, not an executable numerical candidate.

Fresh generation from the pinned Tapenade checkout succeeds in parser,
tangent, and reverse modes.  The parser output `v503_p.f90` is retained only
in the disposable probe and fails strict compilation on the reconstructed
implicit declarations and invalid case structure.  Tangent and reverse emit
their `.msg` diagnostics but no Fortran source because `SYSTEME` has no
active input or output.  This is the applicable strict-compile boundary for
the fresh outputs.

FortAD's exact parser, forward, and reverse requests all stop at the first
allocation statement with
`unsupported allocation lifetime construct 'allocate' at line 80` and write
no output file.  The refusal is preserved for every mode.  No bounded port is
included: declarations, project interfaces, initial values, and callback
semantics are all missing, so any such port would be a different program.

`oracle.py` is independent of the Fortran compiler, Tapenade, and FortAD.  It
checks the source's statement order and models the initial `ErreurNumero = 0`
and `retour = 0` guards, the first reachable allocation frontier, all 14
allocation sites, and the outer-loop termination shape.  It deliberately
reports that no numerical observable is defined by the incomplete source.

Run the complete case evidence from the worker worktree with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v503/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v503/test_contract.py
```

All generated sources, compiler modules, logs, and FortAD outputs are kept in
a disposable `/var/tmp` directory.  Only this case directory is committed.
