# Tapenade `nonRegressions/set01/lh083`

`lh083` is a fixed-form push/pop regression. The exact primal defines
`aa(X,Y)`, increments `j`, updates `X(j)`, and calls `modify(j)`, which changes
the caller-visible `j` before the next iteration. The stored reverse source
uses `PUSHREAL4` and `PUSHINTEGER4` so the backward sweep can restore the
forward indices. No source copy or synthetic wrapper is added to this case.

At the pinned Tapenade revision, fresh `-p`, `-d -root aa`, and `-b -root aa`
probes all generate sources that compile under strict fixed-form flags. The
exact primal and stored reverse source also compile strictly (with only the
expected legacy implicit-interface warnings).

The exact ten-iteration primal is not a safe numerical runtime contract:
the write indices are 7, 17, 37, 77, and then 157. The fifth write is outside
the declared `X(100)` array. Independently, the semantic oracle checks this
prefix and the reverse stack order needed to restore the first four writes.

FortAD at commit `7adc750` accepts the terminal `RETURN` as derivative-neutral:
`check` succeeds and the exact forward product compiles. Reverse refuses
because `X` is read and written in the same loop and needs per-iteration
storage. The exact ten-iteration execution still reaches `X(157)`, so this
case records the forward transformation and its runtime boundary without
claiming a bounded port or silently repairing the array domain. This checkout
is a descendant of the requested baseline `3a946d34`; the runner verifies
that ancestry and records the actual current commit.

Run from the bench repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh083/run.sh
python3 cases/tapenade-set01/lh083/test_contract.py
```
