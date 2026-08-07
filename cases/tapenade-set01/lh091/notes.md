# Tapenade `nonRegressions/set01/lh091`

This is the exact fixed-form `BUGEQUIV(c)` regression and its helper `FF(x)`.
The primal uses `COMMON /CCC/` and `EQUIVALENCE`; `n` is implicit and
uninitialized. The exact source is referenced in the pinned Tapenade checkout,
not copied, normalized, repaired, or ported.

The stored parser, forward, and reverse sources pass strict F2018 and legacy
fixed-form syntax-only gates. The stored multidirectional source
`program_dv.f` fails both gates because it includes the missing
`DIFFSIZES.inc`. The pinned tree contains no authoritative `set01/lh091`
include; unrelated files elsewhere are deliberately not substituted.

Fresh pinned Tapenade probes are:

```text
-p -O <dir> -o lh091 program.f
-d -root bugequiv -O <dir> -o lh091 program.f
-b -root bugequiv -O <dir> -o lh091 program.f
```

All three generate `lh091_p.f`, `lh091_d.f`, and `lh091_b.f`, each passing the
strict and legacy fixed-form syntax gates.

At FortAD `a1c9f25f87eaadf700ba47ee3e841a0fb41585a3`, source-first `check`,
`jvp`, and `vjp` requests refuse at unsupported `COMMON` line 7. Compatibility
`-p`, `-d -root bugequiv`, and `-b -root bugequiv` reach the same exact-source
boundary (the latter two report the compatibility argument-inference wrapper).
No FortAD output is written.

`oracle.py` independently models the defined helper and a one-iteration
observation of the common-state update for three hidden-state cases. It checks
central-difference JVPs and a VJP adjoint identity. This is behavioral
evidence for the defined arithmetic only, not a repaired source or a claim
that the exact routine is runnable with its uninitialized `n`.

Run from the bench repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh091/run.sh
python3 cases/tapenade-set01/lh091/test_contract.py
```
