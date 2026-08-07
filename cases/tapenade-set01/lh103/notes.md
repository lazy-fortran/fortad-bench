# Tapenade `nonRegressions/set01/lh103`

`lh103` is the fixed-form `H` regression for regeneration of loop bounds in a
reverse sweep. The exact source has four local integer bounds that are read
before initialization, and the final expression uses the Fortran post-loop
value of `j`. Those facts make an exact runtime claim inappropriate; the
upstream source is preserved byte-for-byte and only compiler/generator
behavior is recorded.

The pinned Tapenade checkout generates parser, forward, and reverse outputs.
All three fresh outputs pass the strict fixed-form F2018 syntax gate. The fresh
reverse source has the same body as the stored `program_b.f` after removing
only the generated timestamp banner, and its message is byte-identical.

FortAD at the pinned revision parses and re-emits the exact procedure, and its
forward/JVP output strictly compiles. Its reverse/VJP request refuses because
`A` is read and written in one loop and the current engine requires
per-iteration storage; no reverse output is retained.

`oracle.py` is deliberately separate from both tools. It inventories the exact
operation order and evaluates a finite initialized-bound model with arrays large
enough for the post-loop index. It checks a central-difference JVP and an
independent VJP dot-product identity. This is an oracle-only bounded model, not
a repaired Fortran port and not evidence that the uninitialized exact routine
has defined runtime behavior.

Run from the bench repository root:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh103/run.sh
python3 cases/tapenade-set01/lh103/test_contract.py
```

Only this case directory is in scope; generated probe files are disposable
temporary files.
