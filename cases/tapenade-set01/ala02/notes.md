# Tapenade `nonRegressions/set01/ala02`

`ala02` is the pinned nested-fixed-point regression.  The exact source has a
single unambiguous differentiation root, `root(x,y,initial)`, and a local
helper `toto(z,x,oz)`.  The checked-in `Options` file is:

```text
-context -fixinterface -standalonediff
```

The explicit fresh Tapenade commands used by this case are:

```text
tapenade -p -context -fixinterface -standalonediff -O OUT -o ala02 program.f
tapenade -d -root root -context -fixinterface -standalonediff -O OUT -o ala02 program.f
tapenade -b -root root -context -fixinterface -standalonediff -O OUT -o ala02 program.f
```

All three commands generate fresh sources and diagnostics at the pinned
Tapenade revision.  The fresh parser and tangent sources pass both strict
F2018 and legacy fixed-form syntax gates.  The fresh reverse source passes
the legacy gate but refuses strict F2018 because it contains `REAL*8`, just
like the stored reverse reference.  Fresh diagnostics match the stored
diagnostics after removing only the historical default-root line and message
sequence numbers.

The exact source itself passes both syntax gates, as do the stored parser and
forward references.  The source contains `PRINT *,` at line 39, which is an
unsupported FortAD statement.  Both the modern `check`, forward, and reverse
CLI probes and the Tapenade-compatible `-p`, `-d -root root`, and
`-b -root root` probes report that boundary and emit no derivative output.
The source also passes a `REAL` actual (`initial=24.`) to an `INTEGER` dummy
through an implicit interface; Tapenade records this as TC16.  Consequently
there is no exact runtime or repaired Fortran port claimed here.

`oracle.py` independently models only the intended closed arithmetic: the
outer update `z = 2/(oz+x)`, the inner loop skipped by the preceding `oz=z`,
and `y=z*x` for intended initial value 24.0.  It checks a primal result,
finite-difference/JVP agreement, and the scalar VJP adjoint identity.  It
does not read or transform the upstream source and does not invoke either AD
engine.

Run the complete probe from the bench root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/ala02/run.sh
python3 cases/tapenade-set01/ala02/test_contract.py
```

The reproducible gate record is in [`result.txt`](result.txt).
