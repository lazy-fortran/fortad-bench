# Tapenade `todoF90/REFERENCES/v526`: module-bundle and allocation boundary

The pinned v526 directory contains one 1306-line free-form `program.f90` and
seven stored GNU Fortran module files.  The source combines a FoX DOM stub
with the hydraulic procedures `SINGULARITE_REZO`, `REZO`, `SING3`, and
`toplevel`; the selected numeric entry point is `SING3(DXP,DYP,Epaisseur_Seuil)`.

The exact source does not pass the strict F2018 compiler gate.  The FoX
interface uses undeclared `dp` and `sp` kind names and contains an ambiguous
generic interface; later, `M_REZOMAT_T` retains nonstandard `REAL*8`, and the
source's `use Fox_dom` cannot find a `fox_dom.mod` because that module is not a
stored artifact.  The stored references are binary `.mod` files rather than
Fortran source files, so the runner verifies them by strictly compiling a
consumer that imports every stored module.  No historical parser, tangent, or
reverse source is present.

Fresh generation from the pinned Tapenade checkout succeeds for parser,
tangent, and reverse mode with root `SING3`.  Strict compilation of the fresh
parser reproduces the undefined `dp`/`sp` interface boundary; fresh tangent
and reverse compilation stops at the missing `fox_dom.mod`.  These results
are recorded separately from the exact source failure.

FortAD probes the exact unchanged source in all three modes.  It refuses at
the first `allocate` statement (line 233), before reaching `SING3`, and does
not write an output file.  This preserves the exact allocation-lifetime
boundary rather than hiding it behind a repaired module bundle.

The case includes a narrow port of only `SING3`: one-element finite
`double precision` arrays, with `Epaisseur_Seuil` restricted to `1` or `0`.
The port separates initial `DYP` from final `DYP` so the in-place source state
has an unambiguous reverse dependent.  The active branch maps
`DYP = DXP**2`; the inactive branch copies initial `DYP`.  FortAD forward and
reverse products are compiled, linked, and run.  `oracle.py` independently
checks both branch maps with hand JVP/VJP, central differences, and the
adjoint identity.

Run the complete pinned probe from the worker worktree:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v526/run.sh
python3 cases/tapenade-set01/v526/test_contract.py
```

Generated sources, compiler modules, and FortAD output are disposable under
`/var/tmp`; only this case directory is committed.
