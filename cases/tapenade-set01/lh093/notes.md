# Tapenade `nonRegressions/set01/lh093`

`lh093` is the fixed-form `testIOmess` regression for activity warnings around
Fortran I/O. The exact routine reads and writes active variables, performs an
array-section product, and updates `d` from `c`. The upstream checkout at the
recorded revision supplies the exact `program.f` plus one forward reference
(`program_d.f90` and its message file); those files are not copied or repaired.

The exact source and all fresh pinned Tapenade parser, forward, and reverse
outputs pass the legacy compiler gate. The strict F2018 pedantic gate refuses
them because the source uses the legacy comma before an I/O item. The reverse
reference is not asserted because upstream does not provide one.

FortAD at `ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1` refuses exact check,
forward, and reverse at unsupported statement line 8 and writes no output.
This case therefore makes no claim that the interactive procedure is a usable
FortAD port.

`oracle.py` independently inventories the exact I/O/assignment shape and tests
the deterministic array-product/scalar-update projection with a central
difference JVP and a reverse dot-product identity. The projection uses explicit
post-I/O values; it does not execute the interactive exact routine. The contract
file contains exactly three behavioral tests: oracle semantics, fresh Tapenade
generation/compiler gates, and exact FortAD refusal behavior.

Run from the benchmark root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh093/run.sh
python3 cases/tapenade-set01/lh093/test_contract.py
```
