# Tapenade `nonRegressions/set01/lh096`

`lh096` is the fixed-form `testliveness(a,b,c,d)` liveness regression. The routine overwrites `b`, squares `a`, calls `sub1`, and then overwrites `a` again. The exact source and pinned stored `p/d/b` references compile in both fixed-form gates.

The stored multidirectional reference includes `DIFFSIZES.inc`, which is absent from `lh096`. The pinned checkout has unrelated copies in other corpus directories, but none is an unambiguous authoritative dependency for this case. The runner records both compile refusals and does not copy an include or fabricate a vector-mode port.

Fresh pinned Tapenade generation succeeds for `-p`, `-d`, and `-b`; all three generated fixed-form files pass strict and legacy syntax gates. FortAD source-first `check` emits but fails free-form strict syntax on undeclared `sub1`, while forward output passes that gate. Source-first reverse refuses on `assignment to undeclared 'sub1'`. Tapenade-compatibility parser emits an invalid `.f90` on undeclared `sub1`, forward emits a file that passes the free-form gate, and compatibility reverse refuses while inferring its dependent.

`oracle.py` is independent of both tools. It models the final `(a,b,d)` state after the source's overwrites, checks its JVP against central differences, and checks a seeded VJP by an adjoint identity for three meaningful positive-input cases. It is an evidence oracle, not a repaired or supported Fortran port.

Run from the benchmark checkout:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh096/run.sh
python3 cases/tapenade-set01/lh096/test_contract.py
```
