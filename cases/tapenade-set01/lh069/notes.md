# Tapenade `nonRegressions/set01/lh069`

The pinned source is fixed-form `LOOP2(A,B)`. It assigns `A(1)`, repeatedly
recomputes `A(3)`, conditionally copies `B(5:N)` through a `GOTO 100`, and then
assigns `A(7)`. The local integer `N` is declared but never initialized. Thus
the source has no defined control bound: depending on the eventual value of
`N` and the array data, the back-edge can terminate or loop indefinitely.

The stored parser, tangent, and reverse references compile with the strict
fixed-form gate. The stored multidirectional reference is blocked by its
absent `DIFFSIZES.inc` include. Fresh pinned Tapenade generation reproduces
all three single-direction files and each compiles strictly. FortAD refuses
the exact source in both modes at the legacy `CONTINUE` statement on line 6.

The bounded port makes the hidden control explicit as `n`, scalarizes the ten
array elements, and separates input from output values. It is only exercised
with `n=10`, `4*a4>a8` on entry, and `4*a4<=b8` after the copy, so the original
back-edge has exactly one terminating iteration. This is a reproducible
specialization of the observed arithmetic and copy order, not exact support
for the undefined upstream control flow. FortAD JVP generation and selected
VJPs for `ao7` and `bo5` compile and pass the independent hand derivative,
central-difference, adjoint, and compiled-harness checks.

Run with the pinned checkouts available:

```sh
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
  cases/tapenade-set01/lh069/run.sh
python3 cases/tapenade-set01/lh069/test_contract.py
```
