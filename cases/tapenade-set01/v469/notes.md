# Tapenade `todoF90/REFERENCES/v469`: strict free-form tab boundary

The pinned v469 source defines `head(x,y)`, with `pi` imported from
`all_globals_mod` through `anotherModule`, and computes
`y(1) = sin(x(1)*pi2*2)`.  The exact source is retained byte-for-byte.  Strict
free-form compilation rejects its tab characters under `-pedantic-errors`;
the stored tangent and reverse references compile strictly.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds, and all
three generated files strictly compile.  FortAD accepts the exact source and
its parser, forward, and reverse products also strictly compile when the
stored `anothermodule.mod` is on the include path.

The case includes a deliberately narrow standard-conforming port.  It keeps
the one-element `head` map and the exact decimal constant, while making the
domain and intents explicit in a module.  Its domain is finite real(8) arrays
`x(1)` and `y(1)`.  FortAD-generated forward and reverse products are compiled,
linked, and run by the harness.  `oracle.py` is independent of Fortran,
Tapenade, and FortAD; it checks the sine map with central differences and the
JVP/VJP adjoint identity at three points.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v469/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v469/test_contract.py
```

Generated files and compiler modules remain disposable under `/var/tmp`.
