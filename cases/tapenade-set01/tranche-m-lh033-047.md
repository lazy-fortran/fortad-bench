# Tapenade set01 `lh033`, `lh039`, and `lh040`

This tranche keeps the pinned upstream files untouched and exercises three
small fixed-form cases end to end. `lh039` is a supported port with fresh
forward and reverse FortAD output. `lh033` and `lh040` are exact-source
boundary records: Tapenade's parser, tangent, and reverse outputs compile
strictly, while FortAD reports the precise unsupported fixed-form statement.

The runner also compiles the exact upstream primals and runs an independent
Fortran oracle. It checks hand derivatives, central differences, and the
JVP/VJP adjoint identity for `lh039`:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh033_047.sh
```

The committed report is
[`results/tapenade_set01_lh033_047_validation.txt`](../../results/tapenade_set01_lh033_047_validation.txt).
