# Tapenade `nonRegressions/set01/lh087`

`lh087` is the fixed-form Mie-model array-index regression.  The exact
routine declares `phase(10)` and `pp1(10,20)`, then loops `j=1,20` and uses
`phase(j)` and `pp1(j,i)`.  The accesses for `j=11..20` are outside the
declared bounds.  The same loop/index structure is present in the stored
parser, tangent, and reverse files.  This is retained as an exact-source
boundary; no dimensions, loop limits, or root interface are invented here.

The four ordinary stored files compile with strict fixed-form F2018 flags.
The stored multidirectional file is the only stored compile refusal because
it includes `DIFFSIZES.inc`, which is absent from this upstream row.  Fresh
pinned Tapenade parser, tangent, and reverse probes all generate artifacts
that compile strictly.

On the unmodified source at FortAD `7adc750`, forward mode emits a file, but
an independent compiler gate with `-Werror=uninitialized` rejects its
pre-loop `phase(j)*number(k)` expression: `j` and `k` have not been assigned.
The ordinary warning-enabled compile is recorded separately because it still
returns success.  Reverse mode refuses before emission because the exact
source has no `INTENT(OUT)` declaration that lets FortAD recognize `pp` as a
dependent.  These observations are recorded as current behavior, not as
support claims.

`oracle.py` independently checks the strict compiler boundary, the source
index domains, and (when given the generated forward file) the uninitialized
index failure.  `test_contract.py` has exactly three behavioral tests: the
source oracle, fresh Tapenade generation plus compilation, and direct FortAD
forward/reverse behavior.  There is no bounded numerical port because fixing
the array extents or loop bounds would change the exact upstream program.

Run the complete evidence probe from the repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh087/run.sh
```

The complete gate record is in [`result.txt`](result.txt).
