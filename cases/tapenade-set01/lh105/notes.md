# Tapenade `nonRegressions/set01/lh105`

`lh105` is the fixed-form `top(a,b,i)` regression for a special reverse
activity/TBR case. The primal updates `a(i)`, doubles the integer index, and
then updates `a(2*i)` from `b`. Tapenade deliberately keeps `i` out of the
active real derivative set while retaining the first indexed update's value
flow.

The exact `program.f` and stored `program_b.f` both pass strict F2018 and
legacy fixed-form compiler gates. Fresh pinned Tapenade parser, forward, and
reverse generation succeeds, and every fresh output passes both gates.

FortAD at the pinned current-main commit re-emits the exact source and emits a
forward product for independent `a,b`; both outputs pass strict and legacy
free-form gates. Its exact reverse request for dependent `a` and independent
`a,b` returns a generated file with two `a_b` dummy arguments. An independent
compiler rejects that file under both strict and legacy gates with a duplicate
formal-symbol diagnostic. This is recorded as an effective exact reverse
refusal; no source rewrite, repaired port, or synthetic support is claimed.

`oracle.py` is independent of Tapenade and FortAD. It holds the integer index
fixed as discrete control, evaluates the exact two indexed updates, checks the
analytic JVP against central differences, and checks the VJP by an adjoint
dot-product identity. The contract file contains exactly three behavioral
tests: the independent oracle, fresh Tapenade generation with both compiler
gates, and the exact FortAD check/JVP/VJP boundary.

Run from the benchmark repository root:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh105/run.sh
python3 cases/tapenade-set01/lh105/test_contract.py
```

The reproducible gate record is [`result.txt`](result.txt).
