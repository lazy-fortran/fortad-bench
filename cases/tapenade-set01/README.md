# Tapenade set01 support cases

These are the numerical cases promoted from Tapenade's pinned
`nonRegressions/set01` corpus into executable FortAD checks. They were chosen
because each is a small legal Fortran routine with a scalar output and a
closed-form derivative:

- `lh023`: `c = b*b + a/100`
- `lh032`: `y = 2*x**2`
- `lh134`: `f = log(-x)` on `x < 0`
- `lh002`: branch and nested-call state update from `top(x,y,z,a,b,c)`
- `lh049`: `z = 3*(x*y)**2 + x`, followed by the in-place `y = 2*x`

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

## Tranche D: statement-function `min`

The fourth focused runner promotes `lh068`, Tapenade's statement-function
regression. The port keeps `HMIN(CONV)=AMIN1(0.,CONV)` and its two products,
while splitting the overwritten `C(3)` and `C(7)` values into scalar `c3` and
`c7` outputs. The oracle deliberately exercises one active and one inactive
branch away from `conv=0`. Forward mode and separate reverse seeds for both
outputs are checked against hand derivatives, finite differences, and adjoint
identities:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_d.sh
```

See the [case notes](tranche-d.md), [manifest](tranche-d-manifest.toml), and
[measurement record](../../results/tapenade_set01_tranche_d_validation.txt).

## Tranche E: fixed-form in-place state

The fifth focused runner promotes `lh001`, a small fixed-form regression with
two in-place independent writes and a useful scalar result. The port retains
those writes, while the derivative contract treats the initial `i1`, `i2`, and
`i3` as independent and `o1` as the useful dependent; `o2=35` and the final
`o3=2` are checked as constants. The hand oracle reduces the result to
`35*i1*i2**2/(i1-3*i2)` and checks the generated JVP and VJP against a
four-step central-difference sweep and the adjoint identity:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_e.sh
```

See the [case manifest](tranche-e-manifest.toml) and
[measurement record](../../results/tapenade_set01_tranche_e_validation.txt).

## Tranche F: in-place polynomial state

The sixth focused runner promotes `lh049`, a dependency-free fixed-form
regression with a nonlinear result and an in-place output update. The port
retains the `u=x*y`, `z=3*u**2+x`, and final `y=2*x` sequence. Forward and
reverse derivatives use the initial `x,y` as independent state and `z` as the
useful dependent. Final `y` is checked separately:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_f.sh
```

See the [case notes](tranche-f.md), [manifest](tranche-f-manifest.toml), and
[measurement record](../../results/tapenade_set01_tranche_f_validation.txt).

## Tranche G: branch and nested-call state

The seventh focused runner promotes `lh002`, a dependency-free fixed-form
regression with a positive/negative branch and two calls to `sub1`. The port
retains the branch, nested call, in-place updates, and final state while making
the initial `x`, `z`, and `b` explicit independent inputs. The oracle exercises
both branch sides and checks the generated JVP and reverse mode against hand
derivatives, a four-step central-difference sweep, and the adjoint identity:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_g.sh
```

See the [case notes](tranche-g.md), [manifest](tranche-g-manifest.toml), and
[measurement record](../../results/tapenade_set01_tranche_g_validation.txt).

## Tranche I: association-by-address AA components

The eighth focused runner promotes `lh019`, Tapenade's Fortran 2003
`real8_diff` association-by-address regression. It compiles the unmodified
primal and stored `AATypes_aad/aab` references, then checks a scalarized
active-component port (`x%v`, `y%v`) through FortAD forward and reverse modes.
The integer tag field stays passive. Hand JVP/VJP values, four-step central
differences on the product and pass-through branches, and the adjoint identity
are all checked:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_i.sh
```

See the [case notes](tranche-i.md), [manifest](tranche-i-manifest.toml), and
[measurement record](../../results/tapenade_set01_tranche_i_validation.txt).
