# Tapenade `set01/lh073`

`program.f` is a fixed-form `top(A,B)` case.  `top` mutates `A` elementwise,
passes `extf` as an untyped external callback through `toto` and `tutu`, and
then calls `extf(B(10))` again.  The concrete callback is `extf(r) = r*r`, so
the externally visible final state is

```text
A(i) = A_in(i) * B_in(i)
B(i) = B_in(i)**2, i=1..9
B(10) = B_in(10)**4
```

The stored multidirectional derivative `program_dv.f` includes
`DIFFSIZES.inc`, which is not present in the case directory or at the
Tapenade checkout root used by this exact compile.  The other exact and
stored-reference files compile under strict fixed-form flags.  Fresh pinned
Tapenade parser, tangent, and reverse generation also succeeds and all three
fresh files compile strictly.

FortAD refuses the exact entry point while trying to inline `toto`; its
procedure-argument callback is outside the exact supported subset.  A safe
bounded port is included, but it is deliberately not an exact-source claim:
it specializes the observed callback into direct state-map arithmetic, uses
explicit pre-state and post-state arrays, collapses the two concrete
`B(10)` callback applications to the equivalent `B_in(10)**4` map, and adds a
scalar sum objective so that a compiled reverse probe is well-defined.  It
preserves the complete final state map for this concrete `extf`, but does not
claim generic callback, in-place reverse, or `DIFFSIZES.inc` support.

The hand derivative, Python oracle, and compiled harness independently check
the primal state map, JVP, central finite differences, the full adjoint
identity, and the scalar-objective VJP used by the bounded FortAD reverse.

Run with the dedicated checkouts explicitly when this worktree is used:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh073/run.sh
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/lh073/test_contract.py
```
