# Tapenade `nonRegressions/set01/lh107`

`lh107` is a fixed-form scalar regression whose primal is deliberately small
but exercises a seven-actual `MAX` call:

```fortran
      a = max(b,10.0)
      b = max(a,b,3.0,b,a,b,a)
```

The exact `program.f` passes both the strict F2018 and legacy fixed-form
compiler gates. The pinned Tapenade checkout is kept untouched. Its fresh
parser, forward, and reverse commands all generate output and message files.
The parser output passes both compiler gates; the fresh forward output refers
to an undeclared `MAX_D` and fails both gates; the fresh reverse output passes
the legacy gate but fails strict F2018 on `INTEGER*4`. The stored
`program_b.f` has the same strict/legacy boundary. These are recorded as
upstream-generator evidence, not repaired or executable derivative claims.

FortAD at `93f41d60d882778699ec1a887ce9a665a75afcf8` transforms the exact
source through `check` and the direct Tapenade-compatible `-p`, `-d`, and `-b`
forms with `-root test`. Every emitted FortAD source passes the strict free-form
compiler gate. The classification is therefore a runnable exact-source FortAD
port of this case. No Tapenade `MAX_D` implementation, source edit, or
synthetic support file is added.

`oracle.py` independently inventories the exact source and models the two
sequential assignments. Since both final values are `max(b, 10)`, it checks a
central-difference JVP on both sides of the kink and a VJP dot-product identity
for two output seeds. The oracle does not read FortAD or Tapenade output and
does not claim runtime behavior for the unresolved Tapenade forward reference.

`test_contract.py` contains exactly three behavioral tests: the independent
oracle, all exact/stored/fresh Tapenade compiler boundaries, and exact FortAD
CLI generation plus strict compilation.

Run from the benchmark root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh107/run.sh
python3 cases/tapenade-set01/lh107/test_contract.py
```

Only the six files in this directory are part of the case closeout. Generated
probe files are temporary and are not committed.
