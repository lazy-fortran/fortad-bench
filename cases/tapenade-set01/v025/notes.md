# Tapenade `nonRegressions/set04/v025`: module-only reference boundary

The pinned directory contains exactly three tracked files: the exact
`program.f90`, Tapenade's stored parser rendering `program_p.f90`, and its
`program_p.msg`.  The exact source defines modules `a` through `e` and six
`real` module variables.  It contains no `program`, `subroutine`, or
`function` unit, and the parser rendering contains no callable unit either.
The static extractor's no-entry-point classification is therefore not a
missed transformable procedure and not a standalone program; this is a
module-only, reference-only corpus item.

Both exact source files pass the pinned strict free-form compiler gate.  A
fresh Tapenade 3.16 probe at the pinned commit, run without a fabricated root,
emits a parser source and message.  Its forward and reverse probes return
success but emit only message files containing `No root unit to differentiate`
and `The code provided does not contain a top procedure`.  Those messages are
the appropriate fresh-transform evidence for a source with no derivative root;
the stored parser file is not treated as a tangent or reverse reference.

There is no selected entry point, so exact FortAD parser/forward/reverse
requests are not applicable.  FortAD's CLI requires a procedure selection for
those requests; choosing a module name or inventing a wrapper would change the
candidate's interface and semantics.  No bounded port, executable harness,
or numerical derivative claim is included.  `oracle.py` instead provides an
independent semantic check that the source has exactly five declaration-only
modules, six saved real variables, the expected private/public visibility, and
an empty callable/executable domain.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v025/run.sh
python3 cases/tapenade-set01/v025/test_contract.py
```

Generated compiler objects, fresh Tapenade outputs, and logs are disposable
temporary files.  Only this case directory is intended to be committed.
