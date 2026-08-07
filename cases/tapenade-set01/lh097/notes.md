# Tapenade `nonRegressions/set01/lh097`

`lh097` is the fixed-form `testiotbr(a,b,c)` regression for a variable overwritten by an I/O read. The exact source computes `b=a*a`, executes `READ(12, *) , a`, and then computes `c=a*b`. The source is retained only in the pinned Tapenade checkout; this case does not add a port or invent a read value.

At Tapenade `e59864cab441d4175df75383b3ff58c3dcd26df9`, fresh parser, forward, and reverse generation succeeds. Each generated file compiles with the legacy fixed-form gate, while the strict pedantic F2018 gate refuses the legacy comma-before-I/O-item syntax. The stored reverse reference has the same strict-versus-legacy boundary.

At FortAD `ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1`, exact-source `check`, forward, and reverse requests all refuse with `unsupported statement at line 7`; no output file is written.

`oracle.py` is independent of Tapenade and FortAD. It treats the value returned by the external read as a fixed parameter and checks the resulting algebraic JVP against central differences and the VJP against an adjoint identity. This is an evidence oracle, not a repaired source implementation.

Run from the benchmark checkout:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad TAPENADE_REPO=upstream/tapenade cases/tapenade-set01/lh097/run.sh
```
