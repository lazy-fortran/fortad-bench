# Tapenade `nonRegressions/set06/v320`: module-only no-entry boundary

The pinned directory contains exactly `program.f90`, Tapenade's stored parser
rendering `program_p.f90`, and `program_p.msg`. The source is one free-form
`MODULE TEST_TYPEDEF`: it declares private rank-one `foobar` data initialized
to `[0.d0, 1.d0]`, and the derived types `Input` and `Output`. There is no
`PROGRAM`, `SUBROUTINE`, `FUNCTION`, or `CONTAINS` unit, so no callable entry
point or derivative contract exists. There are no stored tangent or reverse
references, and no `Options` file in this row.

The exact source and stored parser reference both pass the strict Fortran 2018
free-form compiler gate. Fresh pinned Tapenade runs without a fabricated root:
parser mode emits `v320_p.f90` and `v320_p.msg`, while tangent and reverse emit
only `v320_d.msg` and `v320_b.msg`. Both derivative messages contain `No root
unit to differentiate` and `The code provided does not contain a top
procedure`; the fresh parser source also passes strict compilation.

The repaired FortAD checkout at commit
`3a946d34d3caa7a75fb6f891139023650b4ce51a` is probed in all three modes
without `--proc`. Parser, forward, and reverse each return the explicit
`fortad: no function or subroutine found in source` refusal and write no
output. The `foobar` names supplied to forward/reverse are existing source
data used only to exercise those CLI modes; they do not select or invent a
procedure, root, or derivative port.

`oracle.py` independently parses the source declaration structure and checks
the module name, private data shape and values, both derived-type field
layouts, and the empty callable/executable domain. It is a semantic inventory
oracle, not a manifest or artifact-existence assertion. No bounded port,
harness, numeric JVP, or VJP is claimed.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v320/run.sh
python3 cases/tapenade-set01/v320/test_contract.py
```

Generated Tapenade files, compiler objects, FortAD output, and logs stay in a
disposable temporary directory. Only this case directory is part of the
commit.
