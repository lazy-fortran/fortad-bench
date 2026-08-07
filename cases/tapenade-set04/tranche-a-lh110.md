# Tapenade set04 `lh110`

This case promotes the smallest viable set04 candidate. The exact upstream
source is compiled and transformed by a fresh Tapenade checkout. Its
`TARGET`/`POINTER` storage-alias and nested-component boundary is currently
rejected by FortAD, so the runnable FortAD port keeps the active storage and
dataflow chain explicit:

```text
x -> le1 -> le2 -> y
```

The port is differentiated in forward and reverse modes. The harness checks
both modes against a hand derivative, a central-difference sweep, and the
adjoint identity.

Run the complete evidence check with:

```sh
scripts/bench_tapenade_set04_lh110.sh
```

The pinned result is recorded in
`results/tapenade_set04_lh110_validation.txt`.
