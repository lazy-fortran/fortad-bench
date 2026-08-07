# Tapenade set01 tranche D

This tranche promotes `lh068`, Tapenade's statement-function regression. The
upstream routine applies `HMIN(CONV)=AMIN1(0.,CONV)` at `i=3,7`. The port keeps
the two products and `min` branches while splitting the two overwritten array
elements into scalar outputs `c3` and `c7`. The split avoids conflating an
in-place dependent with its independent array and makes each reverse seed
explicit.

The test point has `conv(3)<0` and `conv(7)>0`, both with a nonzero margin. The
hand JVP/VJP therefore checks one active and one inactive `min` branch without
sampling the nondifferentiable `conv=0` boundary. FortAD forward mode and two
reverse modes are generated and compiled. Each generated VJP is checked against
the hand oracle, a four-step central-difference sweep, and its JVP/VJP adjoint
identity. The unmodified upstream primal, forward, multidirectional, and
plain-reference files compile with strict gfortran. Tapenade's stored reverse
reference uses its historical `INTEGER*4` spelling, so the runner compiles that
one file explicitly in legacy mode and records the distinction.

Run:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_d.sh
```

The generated measurement is recorded in
[`results/tapenade_set01_tranche_d_validation.txt`](../../results/tapenade_set01_tranche_d_validation.txt).
