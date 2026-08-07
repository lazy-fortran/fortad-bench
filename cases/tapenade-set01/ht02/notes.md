# Tapenade `nonRegressions/set01/ht02`

`ht02` is the fixed-form `top(a)` I/O regression.  The routine initializes
`n`, calls `myopen(n)`, reads `x` from the resulting external unit, and then
updates `a = a*x`.  The source also contains the `myopen` helper and an
`OPEN` statement.  The exact `program.f`, stored reverse `program_b.f`, and
message file are used from the pinned checkout; none is copied or repaired.

The exact source and stored reverse reference pass both strict F2018 and
legacy fixed-form syntax gates.  Fresh pinned Tapenade parser, forward, and
reverse generation also succeeds, and each fresh output passes both gates.
The compiler warning for the implicit `myopen` interface is retained as a
warning; it is not promoted to an error.

FortAD at current main commit `93f41d60d882778699ec1a887ce9a665a75afcf8`
refuses exact `check`, forward, and reverse requests at the external `READ`
on line 7, without writing derivative output.  This is therefore an exact
expected-refusal record, not a repaired port or a synthetic treatment of the
read value.

`oracle.py` is independent of both engines.  It inventories the exact I/O
and assignment shape, then treats the external read value as fixed solely to
check the local multiplication's JVP by central differences and VJP by an
adjoint identity.  It does not execute the interactive exact routine or claim
that FortAD supports external I/O.

Run from the benchmark root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/ht02/run.sh
python3 cases/tapenade-set01/ht02/test_contract.py
```
