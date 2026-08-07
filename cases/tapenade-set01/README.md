# Tapenade set01 support cases

These are the first three numerical cases promoted from Tapenade's pinned
`nonRegressions/set01` corpus into executable FortAD checks. They were chosen
because each is a small legal Fortran routine with a scalar output and a closed
form derivative:

- `lh023`: `c = b*b + a/100`
- `lh032`: `y = 2*x**2`
- `lh134`: `f = log(-x)` on `x < 0`

The ports make types, intents, and `real64` explicit. The arithmetic is
unchanged. The [manifest](manifest.toml) records the exact upstream paths and
entry points. Run the [support runner](../../scripts/bench_tapenade_set01.sh)
after fetching the pinned Tapenade checkout. It compiles each unmodified
fixed-form source as a language-validity oracle, generates and compiles FortAD
JVPs and VJPs, and checks them against hand derivatives, a central-difference
step sweep, and the JVP/VJP adjoint identity. It also writes a [measurement
record](../../results/tapenade_set01_support_validation.txt) with
transformation, derivative-object compilation, runtime, memory, and
generated-code sizes.

The upstream reference derivative files establish that these are Tapenade
regressions, but this benchmark does not count those checked-in files as a
fresh Tapenade run.

## Tranche A: intrinsic chain and in-place refusal

The second focused runner adds `lh088`, the sequential `sqrt`/`log`/power
case. Its port retains all three assignments and adds only `total`, an
oracle-only sum that gives reverse mode one scalar dependent. The runner checks
the unmodified fixed-form source, FortAD JVP and VJP compilation, hand
derivatives, finite-difference convergence, and the adjoint identity:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_a.sh
```

The result is in
[`results/tapenade_set01_tranche_a_validation.txt`](../../results/tapenade_set01_tranche_a_validation.txt).
The exact `lh066` source shape is also retained as an expected refusal:
its in-place `a` is both the dependent state and an independent, so the
current reverse emitter produces duplicate `a_b` dummies and the independent
Fortran compiler rejects the generated file. This is recorded in
[`results/tapenade_set01_refusals.txt`](../../results/tapenade_set01_refusals.txt),
not counted as support.

## Tranche C: Euclidean norm

The third focused runner promotes `lh058`, a dependency-free Euclidean norm
over two arrays. Its [manifest](tranche-c-manifest.toml) fixes the upstream
entry point and the nonzero-norm test domain. The runner checks all five
unmodified primal/reference files, including the stored multi-direction source,
then validates generated JVP/VJP code against hand derivatives, a
four-step finite-difference sweep, and the adjoint identity:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_c.sh
```

See the focused [case notes](tranche-c.md) and the committed
[measurement record](../../results/tapenade_set01_tranche_c_validation.txt).
