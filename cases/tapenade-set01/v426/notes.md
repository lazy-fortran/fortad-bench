# Tapenade `todoF90/REFERENCES/v426`: allocatable lifetime refusal

`v426` is a free-form allocation/context example.  The module `mt` defines
the derived type `t` with an allocatable component `v`; `model_data` saves two
values of that type and `ad_data` saves allocatable input and output arrays.
`setup` allocates all four active arrays, `head` applies the live map

```text
outputs = 2 * (tDataIn%v + inputs)
```

and `cleanallocs` deallocates them.  The exact primal and stored Tapenade
forward reference both compile with strict F2018 flags; the stored message is
an empty historical message file and is preserved as-is.

Fresh generation from the pinned Tapenade checkout succeeds in parser,
tangent, and reverse modes.  The three fresh generated files also strictly
compile.  The `Options` file is retained as corpus evidence, while the runner
passes its equivalent options explicitly so the generation is reproducible.

FortAD's exact parser, forward, and reverse requests all refuse at source
line 4, the allocatable component declaration.  No output file is produced.
No bounded port is included: fixed-size arrays or a module-local replacement
would remove the allocation lifetime and saved derived-type state that define
this case's boundary.

`oracle.py` is independent of the Fortran source, Tapenade, and FortAD.  It
models the setup/cleanup allocation lifecycle and the live array map, checks a
hand JVP against central differences, and checks the matching hand VJP with
an adjoint identity.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v426/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v426/test_contract.py
```

Generated Tapenade files, compiler modules, and FortAD outputs are created in
a disposable `/var/tmp` directory.  `result.txt` records their statuses and
hashes together with the exact pinned-reference hashes.
