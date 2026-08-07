# Tapenade `nonRegressions/set04/v017`: no-entry-point module boundary

The pinned directory contains exactly `README`, `program.f90`,
`program_p.f90`, and an empty `program_p.msg`.  The exact source is a free-form
module named `Z`.  It declares three derived types, the parameter `n = 100`,
an array `ff`, a scalar `bval`, and COMMON block `/vars/`; it contains no
`program`, `subroutine`, or `function` unit.  The static extractor's
`no-entry-point-evidence` classification is therefore correct.  This is not a
standalone program and is not a missed transformable procedure.

`program_p.f90` is a stored Tapenade parser projection, not a derivative
procedure.  It preserves the same module declarations but retains the
historical `SEQUENCE PRIVATE` and `PRIVATE SEQUENCE` lines.  Both that stored
file and the fresh parser output are rejected by strict Fortran 2018
compilation at those lines.  The exact `program.f90` is accepted with only the
Fortran 2018 obsolescent-COMMON warning.

Fresh probes use the pinned Tapenade checkout.  Parser mode produces
`v017_p.f90` and `v017_p.msg`; tangent and reverse mode produce only
`v017_d.msg` and `v017_b.msg`, respectively, with the diagnostics “No root unit
to differentiate” and “The code provided does not contain a top procedure”.
Those are the applicable forward/reverse boundaries for a source with no
entry point.

There is no selected entry point, so exact FortAD parser, forward, and reverse
requests are inapplicable.  The runner records that principled no-entry
boundary rather than inventing a procedure name or a refusal location.  No
bounded port or numerical derivative oracle is claimed.  `oracle.py` is an
independent semantic oracle for the declaration inventory, COMMON layout, and
absence of executable units; it reports the numerical observable as undefined
because the corpus supplies no executable procedure.

All fresh files, compiler modules, logs, and FortAD probe paths are disposable
under `/var/tmp`.  Only this case directory is changed and committed.

Run the complete evidence probe from this worker worktree with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v017/run.sh
python3 cases/tapenade-set01/v017/test_contract.py
```
