# Tapenade `nonRegressions/set06/v362`: module-only no-entry boundary

The pinned directory contains the exact free-form source, Tapenade's stored
parser rendering, and an empty stored parser message.  `program.f90` defines
only modules `M0` and `M1`: `M0` initializes `m0_i`, while `M1` uses `M0` and
declares the private module state `gm_show` and `gm_unit`.  There is no
`program`, `subroutine`, `function`, or `contains` unit.

The exact source and stored parser reference both compile with strict
free-form Fortran 2018 flags.  The only diagnostics are the expected
`Unused PRIVATE module variable` warnings for `gm_show` and `gm_unit`.

Fresh pinned Tapenade parser generation emits `v362_p.f90` and the empty
`v362_p.msg`; the generated parser source also passes the strict compiler
gate.  Fresh tangent and reverse generation exits successfully but emits
only `v362_d.msg` and `v362_b.msg`, each containing `No root unit to
differentiate` and `The code provided does not contain a top procedure`.

The repaired FortAD 3a946d3 CLI is probed on the exact source without a
fabricated `--proc`.  Its parser, forward, and reverse requests all exit
nonzero with `fortad: no function or subroutine found in source` and write no
output file.  This is the expected no-callable-entry boundary; naming a
module as a root or adding a wrapper would change the candidate.

`oracle.py` independently inventories the source text, checking the two
module names, their declarations and initializers, and the empty callable
domain.  It is a semantic source oracle, not a manifest or artifact-existence
assertion.  No synthetic root, derivative port, or numerical derivative claim
is included.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v362/run.sh
python3 cases/tapenade-set01/v362/test_contract.py
```

Generated Tapenade files, compiler objects, FortAD output, and logs stay in a
disposable temporary directory.  Only this case directory is part of the
commit.
