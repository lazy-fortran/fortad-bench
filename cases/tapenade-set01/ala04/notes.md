# Tapenade `nonRegressions/set01/ala04`

This case retains the pinned exact source at
`upstream/tapenade/nonRegressions/set01/ala04`. Its selected procedure is
`FP2(x,y)`, with an outer fixed-point loop, an inner fixed-point loop, and
checkpointed calls to `TOTO`. The checked-in `Options` file contains only
`-context`; pinned Tapenade therefore selects `FP2` as the default root:

```text
tapenade -p -context -O OUT -o ala04 program.f
tapenade -d -context -O OUT -o ala04 program.f
tapenade -b -context -O OUT -o ala04 program.f
```

All three fresh transformations succeed and reproduce the stored parser,
forward, and reverse sources after ignoring only the Tapenade banner line.
Fresh and stored message files agree after removing only their numeric line
prefix. The exact source and every generated/stored artifact use `REAL*8`:
they pass the legacy fixed-form syntax gate and are rejected by strict F2018.
The context derivative artifacts call Tapenade runtime routines, so this case
does not claim to link or run them.

The exact primal source does link and run under the legacy compiler. Its
output is approximately `y = 0.9999999999490585` for the source's `x=1.0`.
The independent `oracle.py` separately implements the two nested scalar
recurrences, checks that primal result and iteration accounting, compares a
hand JVP with central differences, and checks a hand VJP by the dot-product
identity. It exposes initialized `z=24` only as an internal oracle state; the
exact source has only `x` as an independent argument.

Against the unchanged exact source, current FortAD's `check` exits zero but
re-emits an incomplete `FP2`: the output omits the `REAL*8` declarations and
the `DO WHILE` body. Forward refuses with
`independent 'x' is not declared in FP2`, and reverse refuses with
`dependent 'y' is not declared in FP2`; neither derivative request writes an
output file. These are recorded parser-boundary results, not a repaired port.

Reproduce the complete evidence from the bench root:

```sh
./cases/tapenade-set01/ala04/run.sh
python3 cases/tapenade-set01/ala04/test_contract.py -v
```

The runner accepts `TAPENADE_REPO`, `FORTAD_REPO`, and `FC` overrides while
still requiring the pinned revisions by default.
