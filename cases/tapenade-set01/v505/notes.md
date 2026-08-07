# Tapenade `todoF90/REFERENCES/v505`: external-callback interface boundary

`v505` contains a small, strict-compilable module `M` and external function
`top(r,s)`.  The inputs are rank-one real arrays of length `n = 2`.  `top`
passes an interface-only callback `compute` to the external function `ftest`:

```fortran
top = ftest(r,s,compute)
```

The exact directory stores the primal, one forward tangent reference, and the
forward message.  It has no parser reference, reverse reference, or
implementations of `ftest`/`compute`.  The exact primal and stored tangent
compile under the case's strict flags; the only diagnostics are warnings for
the external calls' implicit interfaces.  Their object files are not linked,
because no external callback semantics are supplied by the corpus.

Fresh generation from pinned Tapenade succeeds in parser, forward, and reverse
modes, and all three generated sources compile strictly.  The parser message
records the assumed activity of `ftest`; the tangent and reverse messages
request a differential for that missing external routine.

FortAD's exact parser, forward, and reverse requests all refuse at the
interface block beginning on line 12 with `unsupported statement at line 12`.
No output is produced in any mode.  This boundary is preserved rather than
flattening the interface or inventing an implementation of `ftest`.

`oracle.py` is independent of the Fortran compiler, Tapenade, and FortAD.  It
checks the callback graph and shape contract from the source: `top` consumes
two length-two real vectors, passes the interface procedure `compute` as the
third actual argument to `ftest`, and has no local expression defining a
numeric result.  It therefore reports a semantic underdetermination, not a
fabricated numerical derivative.

Run the complete case evidence from the worker worktree with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v505/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v505/test_contract.py
```

All generated sources, compiler modules, logs, and FortAD outputs are kept in
a disposable `/var/tmp` directory.  Only this case directory is committed.
