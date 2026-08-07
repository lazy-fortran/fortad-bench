# Tapenade `nonRegressions/set05/v216`: module-only reference boundary

The pinned directory contains exactly `program.f90`, Tapenade's stored parser
rendering `program_p.f90`, and an empty `program_p.msg`. The exact source
defines the `definition` module with the `wp` kind parameter and the `rk`
module with private real module state `t`. It contains no `program`,
`subroutine`, `function`, or `contains` unit, so there is no callable entry
point and no derivative contract.

The exact source and stored parser reference both pass the strict free-form
Fortran gate. GNU Fortran reports only the expected `-Wall` warning that the
private module variable `t` is unused. Fresh pinned Tapenade run without a
fabricated root emits `v216_p.f90` and `v216_p.msg`; the parser source also
passes the strict compiler gate. Fresh tangent and reverse runs emit only
`v216_d.msg` and `v216_b.msg`, each recording `No root unit to differentiate`
and `The code provided does not contain a top procedure`.

FortAD is probed on the exact source with parser, forward, and reverse
requests and no `--proc` selection. Each request refuses with
`fortad: no function or subroutine found in source` and emits no output. This
is the reproducible no-entry boundary; naming a module as a root or adding a
wrapper would invent a callable interface.

`oracle.py` independently parses the declaration structure and checks the two
modules, the kind parameter, the private module variable, and the empty
callable/executable domain. It is a semantic inventory oracle, not a manifest
or artifact-existence check. No bounded port or numerical derivative claim is
included.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v216/run.sh
python3 cases/tapenade-set01/v216/test_contract.py
```

Generated Tapenade files, compiler objects, FortAD output, and logs stay in a
disposable temporary directory. Only this case directory is part of the
commit.
