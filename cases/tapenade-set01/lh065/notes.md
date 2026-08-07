# Tapenade `nonRegressions/set01/lh065`

`lh065` is a fixed-form warning/regression case whose entry point is
`top(in,out,N)`.  Its purpose is to exercise diagnostics around activity lost
when REAL values are passed to INTEGER dummy arguments and around active and
useful variables crossing dirty side-effect routines.  The source also places
REAL*8 `varcom` in `/comvarcom/` in `TOP`, but declares the same COMMON member
as an INTEGER in `DIRTYWRITE` and `DIRTYREAD`.  That changes the COMMON layout
and is not a standard-conforming, semantics-preserving boundary to port.

The available exact/stored source set is `program.f`, `program_p.f`, and
`program_d.f`; their corresponding `.msg` files are present.  There is no
`program_b.f`, `program_b.msg`, or `program_dv.f` in the pinned upstream row,
so the runner records those references as missing rather than treating them as
successful or inventing replacements.

All three available exact/stored sources refuse the strict fixed-form F2018
compiler gate.  The failures include nonstandard `REAL*8` declarations and
cascading invalid declarations/calls caused by the source's implicit and
inconsistent REAL/INTEGER boundaries.  Fresh pinned Tapenade parser, tangent,
and reverse generation succeeds, but all three fresh outputs refuse the same
strict compiler gate.

FortAD is run on the unmodified `program.f` in forward and reverse mode with
`in` independent and `out` dependent.  Both modes refuse at the COMMON
declaration on line 9 before emitting output.  No bounded port is included:
changing REAL*8 to a standard kind, changing `dirtyRead`/`dirtyWrite` to REAL
callbacks, or making the COMMON declarations agree would select semantics not
defined by the upstream case.  The independent oracle therefore checks the
strict compiler diagnostic boundary, not a fabricated numerical derivative.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/path/to/fortad-at-0e15604 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh065/run.sh
python3 cases/tapenade-set01/lh065/test_contract.py
```

The complete gate record is in [`result.txt`](result.txt).
