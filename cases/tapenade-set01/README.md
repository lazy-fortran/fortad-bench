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
- `lh004`: bounded reverse refusal for a branch inside a loop; the fixed-trace
  primal and forward path remain independently checked
- `lh019`: scalarized active `real8_diff` component with a passive integer tag;
  forward and reverse paths remain independently checked

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

The ninth focused runner promotes `lh019`, Tapenade's Fortran 2003
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

## Tranche H: bounded branch-in-loop refusal

The tenth focused runner records `lh004`, whose `tata(y,z,x)` routine has a
data-dependent stopping branch inside a loop. The port keeps the bounded loop
and checks its fixed four-iteration primal trace at positive and negative `z`
with an independent hand JVP/VJP, central differences, and an adjoint
identity. FortAD forward mode generates and compiles, while reverse mode
returns the exact `a branch inside a loop needs control-flow reversal`
diagnostic. This is a reproducible expected refusal, not a support claim:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_tranche_h.sh
```

See the [case notes](tranche-h.md), [manifest](tranche-h-manifest.toml), and
[measurement record](../../results/tapenade_set01_tranche_h_refusal_validation.txt).

## Tranche L: `lh017`, `lh022`, and `lh028`

The next runner closes three adjacent pure-Fortran rows. `lh017` is a
piecewise branch with complete forward and reverse support. `lh022` and
`lh028` have passing forward transforms and independent hand, finite
difference, and adjoint checks, while reverse mode records distinct exact
boundaries for per-iteration storage and control-flow reversal:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh017_032.sh
```

See the [case notes](tranche-l-lh017-032.md),
[manifest](tranche-l-lh017-032-manifest.toml), and
[measurement record](../../results/tapenade_set01_lh017_032_validation.txt).
The `lh019` derived-component result is in
[the tranche-I record](../../results/tapenade_set01_tranche_i_validation.txt).

## `lh007`-`lh015` tranche: exact-source generated-compile boundaries

The focused `lh007`-`lh015` probe closes `lh012`, `lh013`, and `lh014` as
reproducible expected refusals. It compiles each exact upstream source and
stored reference, regenerates and strictly compiles fresh Tapenade parser,
tangent, and reverse files, then records FortAD's generated-code compiler
boundary. `lh012` and `lh013` retain a compilable forward path while reverse
generation fails. `lh014` relies on implicit loop-index typing, which FortAD's
`implicit none` derivative does not declare. The independent harness checks
safe indexed-product, initialized-scalar, and output-sum observations with
hand JVP/VJP, central differences, and adjoint identities.

See the [case notes](tranche-l-lh007-015.md),
[manifest](tranche-l-lh007-015-manifest.toml), [runner](../../scripts/bench_tapenade_set01_lh007_015.sh),
and [measurement record](../../results/tapenade_set01_lh007_015_refusal_validation.txt).

## Tranche M: `lh033`, `lh039`, and `lh040`

The adjacent `lh033`/`lh039`/`lh040` runner keeps three exact fixed-form
sources in the pinned checkout. `lh039` is a supported nested-call port with
forward and reverse output. `lh033` (a `COMMON` block) and `lh040` (a fixed-form
`CHARACTER*10` declaration) are reproducible exact-source refusals with fresh
Tapenade parser, tangent, and reverse outputs compiled strictly and the exact
FortAD diagnostic recorded. The independent harness checks both refusal
primals and the supported case with hand derivatives, central differences, and
the JVP/VJP adjoint identity:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh033_047.sh
```

See the [case notes](tranche-m-lh033-047.md), [manifest](tranche-m-lh033-047-manifest.toml),
and [measurement record](../../results/tapenade_set01_lh033_047_validation.txt).

## Tranche N: `lh085` and `lh092`

The adjacent `lh085`/`lh092` runner closes two pure-Fortran rows with fresh
Tapenade parser, tangent, and reverse generation. `lh085` checks a large
expression with active array elements through forward and reverse modes;
`lh092` checks a nested-call split with both scalar inputs active. Both ports
pass independent hand derivatives, a central-difference directional check, and
the JVP/VJP adjoint identity:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh083_096.sh
```

See the [case notes](tranche-n-lh083-096.md),
[manifest](tranche-n-lh083-096-manifest.toml), and
[measurement record](../../results/tapenade_set01_lh083_096_validation.txt).

## Tranche O: `lh086`

The `lh086` runner closes the Newton-map case with fresh Tapenade parser,
tangent, and reverse generation. The exact upstream routine updates `x` in
place; the FortAD case is a bounded port that exposes the final iterate as
`y`, making the independent variables and dependent explicit. Its hand
Newton-map JVP/VJP, central-difference sweep, and adjoint identity all pass:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh086.sh
```

See the [case notes](tranche-o-lh086.md),
[manifest](tranche-o-lh086-manifest.toml), and
[measurement record](../../results/tapenade_set01_lh086_validation.txt).

## Tranche P: `bd05` and legacy loop indices

The `bd05` runner preserves the upstream `HEAD`/`LEAF` call chain and both
product loops, while exposing the mutated array and scalar as ordinary port
outputs. The exact fixed-form upstream and freshly generated Tapenade files
compile under strict legacy flags. FortAD forward and reverse transforms pass
the independent hand JVP/VJP, central-difference sweep, and adjoint identity.
The case also verifies that generated `implicit none` procedures synthesize an
`integer` declaration for a legacy implicit `DO` index:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_bd05.sh
```

See the [manifest](tranche-p-bd05-manifest.toml), [runner](../../scripts/bench_tapenade_set01_bd05.sh),
and [measurement record](../../results/tapenade_set01_bd05_validation.txt).

## Tranche Q: `lh018`

The `lh018` runner preserves the exact fixed-form upstream source and stored
`program_b.f`/`program_d.f` references, then regenerates fresh Tapenade parser,
tangent, and reverse sources and compiles every generated file strictly. The
exact source mutates a dead function argument, so the bounded FortAD port makes
that argument passive and exposes the resulting scalar output explicitly. Its
closed form is `a_out = 343*b*c(10)`; the hand JVP/VJP, central-difference sweep,
and VJP/JVP adjoint identity all pass independently:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh018.sh
```

See the [manifest](tranche-q-lh018-manifest.toml), [case notes](tranche-q-lh018.md),
and [measurement record](../../results/tapenade_set01_lh018_validation.txt).

## Tranche R: `lh007`, `lh009`, `lh011`, and `lh015`

This refusal tranche records four additional exact-source boundaries. `lh007`
passes strict primal and fresh Tapenade compilation but stops at the upstream
`COMMON` block. `lh011` stops at computed `GOTO` while its fresh reverse output
also fails strict compilation. `lh009` and `lh015` preserve invalid upstream
Fortran classifications rather than repairing their conflicting declarations or
type-invalid loop expressions. Each runner retains the pinned source,
generated-source diagnostics, and an independent bounded hand/finite-difference
or adjoint oracle; the bounded ports are not support claims for the exact source.

Run the cases individually with their linked runners:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh007.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh011.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh015.sh
```

See the [`lh007` notes](lh007.md), [`lh009` notes](lh009.md),
[`lh011` notes](tranche-q-lh011.md), [`lh015` notes](tranche-lh015.md), and
their corresponding manifests and measurement records.

## Tranche S: `lh020`, `lh021`, `lh024`, `lh025`, `lh026`, and `lh027`

This tranche closes six adjacent fixed-form rows with independent case-local
runners. `lh020`, `lh025`, and `lh027` provide bounded standard-conforming
ports whose JVP/VJP checks pass hand, finite-difference, and adjoint oracles;
their exact sources remain visible where legacy control flow is unsupported.
`lh021`, `lh024`, and `lh026` record exact-source refusal boundaries while
their bounded observations still pass independent numerical checks. Every
case retains strict upstream/reference compilation, fresh pinned Tapenade
parser/tangent/reverse generation, and machine-readable results:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh020.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh021/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh024.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh025.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh026.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh027.sh
```

See the [lh020 manifest](lh020-manifest.toml), [lh021 notes](lh021/notes.md),
[lh024 manifest](lh024-manifest.toml), [lh025 manifest](tranche-lh025-manifest.toml),
[lh026 manifest](tranche-lh026-manifest.toml), [lh027 manifest](lh027-manifest.toml),
and the six linked result records.

## Tranche T: `lh029`, `lh030`, `lh031`, `lh034`, `lh035`, and `lh036`

This tranche closes the next six fixed-form rows. `lh029`, `lh030`, and
`lh031` retain exact upstream and fresh Tapenade evidence while validating
bounded standard-conforming ports against independent JVP/VJP, finite-
difference, and adjoint checks. `lh034` records an exact callback/`RETURN`
boundary with a passing bounded forward oracle. `lh035` and `lh036` are
invalid-upstream closures: their conflicting declarations or missing external
semantics do not justify a repaired numerical port. Each case has a pinned
runner, machine-readable result, and contract test.

The runners are:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh029.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh030/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh031.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh034.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh035/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh036/run.sh
```

See the case manifests and result records under `cases/tapenade-set01/lh029/`
through `lh036/` and `results/tapenade_set01_lh029_validation.txt` through
`results/tapenade_set01_lh034_validation.txt`.

## Tranche U: `lh037`, `lh038`, `lh041`, `lh042`, `lh044`, and `lh045`

This tranche closes six more fixed-form rows with exact-source and fresh
Tapenade evidence. `lh037`, `lh042`, and `lh044` are invalid-upstream
closures: deleted assigned `GOTO`, declaration/kind conflicts, missing
includes, and an `INTRINSIC`/dummy conflict make repaired numerical ports
semantically unsafe. `lh038`, `lh041`, and `lh045` retain exact FortAD
refusals while bounded forward paths pass independent hand, finite-difference,
and adjoint checks; their bounded reverse compile boundaries remain recorded.
Every case has a pinned runner and a 3-test contract oracle.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh037/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh038/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh041/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh042/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh044/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh045/run.sh
```

See the case manifests, result records, and independent contract tests under
`cases/tapenade-set01/lh037/`, `lh038/`, `lh041/`, `lh042/`, `lh044/`, and
`lh045/`.

## Tranche V: `lh046`, `lh047`, `lh048`, `lh050`, `lh051`, and `lh053`

This tranche closes six further fixed-form rows. `lh047`, `lh048`, `lh051`,
and `lh053` preserve exact FortAD refusal boundaries while bounded forward
ports pass independent hand, finite-difference, and adjoint checks. `lh046`
is invalid upstream because of `REAL*16` and malformed indexed `READ` syntax.
`lh050` is deliberately recorded as a semantic-mismatch refusal: exact FortAD
forward and reverse code compiles but fails the independent oracle on the
conditional branch, while an explicit-`INTENT` bounded forward port passes.
It is not a support claim. All six retain fresh Tapenade evidence and 3-test
case contracts.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh046/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh047/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh048/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh050/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh051/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh053/run.sh
```

See the manifests, results, independent oracles, and contract tests under the
six corresponding `cases/tapenade-set01/lh0*/` directories.

## Tranche W: `lh054`, `lh055`, `lh056`, `lh059`, `lh060`, and `lh061`

This tranche closes six more fixed-form rows with exact-source and fresh
Tapenade evidence. `lh054` is a FortAD semantic/code-generation mismatch on
an alternate-return and implicit interface; its bounded forward witness
passes while exact forward/reverse output is rejected by the compiler.
`lh055`, `lh059`, and `lh060` retain exact-source refusals with bounded
forward witnesses checked by independent hand, finite-difference, and
adjoint oracles. `lh056` is invalid upstream because its three-argument,
mixed-kind `AMIN1` call has no standard-defined meaning. `lh061` remains an
unresolved callback boundary: adding callback bodies or derivative rules
would define a different program, so no bounded numerical port is claimed.
Every case has fresh pinned Tapenade parser/tangent/reverse evidence and a
three-test local contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh054/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh055/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh056/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh059/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh060/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh061/run.sh
```

See the manifests, results, independent oracles, and contract tests under
the six corresponding `cases/tapenade-set01/lh0*/` directories.

## Tranche Z: `todoF90/REFERENCES/bd01`, `bd11`, `v01`, `v02`, `v05`, and `v07`

This historical-reference tranche closes six pure-Fortran queue rows. `bd01`
and `bd11` retain exact FortAD refusals at a module-call or array-section
boundary while bounded ports pass independent hand, finite-difference, adjoint,
and compiled-harness checks. `v01` records an exact refusal for persistent
allocatable module state and external NetCDF-style callbacks without claiming a
repair. `v02` retains exact parser/forward/reverse compile refusals while an
explicit-state bounded port passes the same independent gates. `v05` and `v07`
are invalid-upstream closures with no semantics-preserving port. Every case has
fresh pinned Tapenade evidence and a three-test local contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/bd01/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/bd11/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v01/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v02/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v05/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v07/run.sh
```

See the manifests, result records, and independent contract tests under
`cases/tapenade-set01/bd01/`, `bd11/`, `v01/`, `v02/`, `v05/`, and `v07/`.

## Tranche AA: `todoF90/REFERENCES/v100`, `v101`, `v144`, `v270`, `v322`, and `v377`

This tranche closes six historical-reference rows. `v100` and `v101` retain
exact FortAD refusals for MOD and allocatable lifetime while bounded forward and
reverse witnesses pass independent numerical contracts. `v144`, `v270`, `v322`,
and `v377` are invalid-upstream closures covering implicit-interface/rank,
legacy-kind/allocatable state, missing derivative runtime dependencies, and MPI
argument/communication errors. Each case has fresh pinned Tapenade evidence and
a three-test local contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v100/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v101/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v144/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v270/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v322/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v377/run.sh
```

See the manifests, result records, oracles, and contract tests under
`cases/tapenade-set01/v100/`, `v101/`, `v144/`, `v270/`, `v322/`, and `v377/`.

## Tranche AB: `todoF90/REFERENCES/v385`, `v402`, `v412`, `v413`, `v414`, and `v415`

This tranche closes six more historical-reference rows. `v385`, `v402`, and
`v412` are invalid-upstream closures covering MPI/allocatable state, a
zero-actual call plus missing `DIFFSIZES`, and mixed-kind implicit interfaces.
`v413` records an undefined local exponent, while `v414` and `v415` retain
FortAD refusal boundaries for private derived types and allocatable components.
Fresh pinned Tapenade generation and strict compilation are recorded for every
case, and each has an independent three-test contract. No bounded port is
claimed for this tranche.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v385/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v402/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v412/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v413/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v414/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v415/run.sh
```

See the manifests, result records, independent oracles, and contract tests
under `cases/tapenade-set01/v385/`, `v402/`, `v412/`, `v413/`, `v414/`, and
`v415/`.

## Tranche AC: `todoF90/REFERENCES/v416`, `v417`, `v418`, `v419`, `v421`, and `v422`

This tranche closes six historical-reference rows. `v416` retains an exact
declaration-order refusal and adds a bounded, independently checked port.
`v417` and `v419` retain allocatable/context-association refusal boundaries.
`v418` and `v421` are invalid-upstream MPI and explicit-shape cases, while
`v422` records an undefined function-result/code-generation boundary. Every
case has fresh pinned Tapenade evidence and an independent three-test contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v416/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v417/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v418/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v419/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v421/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v422/run.sh
```

See the manifests, result records, independent oracles, and contract tests
under `cases/tapenade-set01/v416/`, `v417/`, `v418/`, `v419/`, `v421/`, and
`v422/`.

## Tranche AD: `todoF90/REFERENCES/v425`, `v426`, `v427`, `v469`, `v500`, and `v503`

This tranche closes six historical-reference rows. `v425`, `v426`, `v427`, and
`v500` retain refusal boundaries for module parsing, allocatable lifetimes,
allocatable module state, and `DATA`/singular normalization. `v469` adds a
bounded one-element port for the strict tab boundary. `v503` is an incomplete
invalid-upstream program with no stored references. Every case has fresh pinned
Tapenade evidence and an independent three-test contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v425/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v426/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v427/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v469/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v500/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/v503/run.sh
```

See the manifests, result records, independent oracles, and contract tests
under `cases/tapenade-set01/v425/`, `v426/`, `v427/`, `v469/`, `v500/`, and
`v503/`.

## Tranche Y: `lh071`, `lh072`, `lh073`, `lh075`, `lh076`, and `lh077`

This tranche closes six more fixed-form rows. `lh071` and `lh075` are
invalid-upstream closures: rank-mismatched calls, invalid pointer targets, and
a subroutine used as a function leave no exact semantics to preserve. `lh072`,
`lh073`, `lh076`, and `lh077` retain exact FortAD refusals while bounded
callback, complex-kind, or explicit-interface specializations pass independent
hand, finite-difference, adjoint, and compiled-harness checks. The bounded
specializations are explicitly scoped and are not exact-source support claims.
Each case has a three-test local contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh071/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh072/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh073/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh075/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh076/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh077/run.sh
```

See the manifests, results, independent oracles, and contract tests under
the six corresponding `cases/tapenade-set01/lh0*/` directories.

## Tranche X: `lh063`, `lh064`, `lh065`, `lh067`, `lh069`, and `lh070`

This tranche closes six further fixed-form rows with strict exact-source and
fresh pinned Tapenade evidence. `lh063` and `lh065` are invalid-upstream
closures: duplicate global definitions, invalid callback kinds, and changing
COMMON layouts do not admit a semantics-preserving repair. `lh064`, `lh067`,
`lh069`, and `lh070` retain exact FortAD refusal boundaries while bounded
specializations pass independent hand, finite-difference, adjoint, and/or
compiled-harness checks. The bounded paths expose hidden state or control
flow and are not exact-source support claims. Every case has a three-test
local contract.

Run the cases individually with:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh063/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh064/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh065/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh067/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh069/run.sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh070/run.sh
```

See the manifests, results, independent oracles, and contract tests under
the six corresponding `cases/tapenade-set01/lh0*/` directories.
