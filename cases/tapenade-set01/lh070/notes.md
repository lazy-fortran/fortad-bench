# Tapenade `nonRegressions/set01/lh070`

`lh070` differentiates the fixed-form `top(A,B)` routine.  The routine keeps
`x`, `y`, and `z` in `COMMON /cc/`, updates `A(1)`, calls `F` (which computes
`y=x*z` and then overwrites `x` with `3.0`), and finally updates `B(1)`.

The exact primal and stored parser, tangent, and reverse references compile
with the strict fixed-form gate.  The stored multidirectional reference is
blocked only by the absent `DIFFSIZES.inc`.  Fresh pinned Tapenade parser,
tangent, and reverse generation succeeds and all three fresh outputs compile
strictly.

FortAD refuses both exact modes at the first `COMMON /cc/` declaration (line
4).  This is recorded as an expected exact-source refusal, not silently
rewritten support.

The case-local `port.f90` makes the COMMON values explicit while preserving
the observed operation order and array shapes.  Its forward probe differentiates
the full explicit state `(a,b,x,z)`; its reverse probe asks for the final scalar
`y` and checks the corresponding adjoints.  The bounded witness is checked by
an independent hand JVP/VJP, central-difference sweep, scalar adjoint identity,
and a compiled harness against FortAD's generated forward and reverse code.
It is a bounded numerical witness, not exact support for hidden COMMON state.

Run the complete probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh070/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
