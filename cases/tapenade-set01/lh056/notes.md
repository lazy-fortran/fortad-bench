# Tapenade `nonRegressions/set01/lh056`

`lh056` is a fixed-form intrinsic-regression case rooted at `f(t)`. The
primal computes `exp(t*t)` and then calls `AMIN1(f, 0.9, 5)` even though the
declared intrinsic call has three arguments with incompatible kinds. Under
the pinned strict `gfortran` gate, the exact primal and the older `program_p.f`
reference fail at that call. The stored `program_d.f` and `program_b.f`
references syntax-check, while `program_dv.f` additionally depends on the
missing `DIFFSIZES.inc` include.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds with
the recorded roots and emits all three outputs. Strict compilation of the
fresh parser output reproduces the invalid `AMIN1` diagnostic; fresh tangent
and reverse outputs syntax-check but contain external differentiated-intrinsic
and reverse-stack calls, so this is not executable derivative evidence.

FortAD is run on the exact source in forward and reverse modes. It refuses at
the `INTRINSIC AMIN1` declaration and emits no transform. There is no bounded
port, hand derivative, finite-difference sweep, or adjoint identity: changing
the argument count or kinds would invent semantics for an invalid upstream
row. The independent oracle is therefore the compiler diagnostic contract,
not a numerical derivative check.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh056/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
