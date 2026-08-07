# Tapenade set01 support cases

These are the first three numerical cases promoted from Tapenade's pinned
`nonRegressions/set01` corpus into executable FortAD checks. They were chosen
because each is a small legal Fortran routine with a scalar output and a closed
form derivative:

- `lh023`: `c = b*b + a/100`
- `lh032`: `y = 2*x**2`
- `lh134`: `f = log(-x)` on `x < 0`

The ports make types, intents, and `real64` explicit; the arithmetic is
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
