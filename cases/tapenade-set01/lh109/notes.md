# Tapenade `nonRegressions/set01/lh109`

`lh109` is the fixed-form `ADJ3(z,t)` regression.  It uses the `cc` COMMON
block in both `ADJ3` and `SUB1`, passes `x(i)` to a dummy declared as
`REAL(0:6)`, and updates state through several implicit aliases.  The exact
source also reads `u`, `v`, and `j` before they are initialized.  The pinned
stored reverse reference reports the same type-mismatch and aliasing concerns
and calls Tapenade's external stack procedures.

The exact source and stored reverse source pass both the strict F2018 and
legacy fixed-form syntax-only gates.  Fresh pinned Tapenade parser, forward,
and reverse generation also succeeds; every fresh output passes both gates.
The fresh reverse body equals `program_b.f` after removing the generated
banner.  The fresh reverse diagnostic content matches the stored message after
removing the default-root selection line and generated sequence numbers.

FortAD at `93f41d60d882778699ec1a887ce9a665a75afcf8` refuses exact `check`,
forward, and reverse requests at `COMMON` line 6, without writing output.
This is an exact-source expected refusal.  No COMMON implementation, alias
repair, initialization, stack runtime, or repaired Fortran port is included.

`oracle.py` is independent of both tools.  It inventories the exact source
shape and checks a separately named bounded model of the deterministic
arithmetic in `SUB1`, with formerly undefined values explicitly initialized.
It verifies a central-difference JVP and an independent VJP dot-product
identity.  That bounded projection is evidence for the arithmetic only; it is
not a runtime claim about the exact `ADJ3` procedure.

Run from the benchmark repository root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh109/run.sh
python3 cases/tapenade-set01/lh109/test_contract.py
```

The runner writes the reproducible gate record to `result.txt` and removes
all generated probe files on exit.
