# Tapenade set01 tranche J/lh016: complex arithmetic

`lh016` overwrites each output twice in a two-step inner loop, leaving
`out(1)=(1+2i)*in(1)` and `out(2)=(2+2i)*in(1)`. The port changes only the
legacy complex-literal spelling and adds explicit intents.

FortAD's generated JVP compiles and passes a real-coordinate directional
finite-difference oracle. Tapenade's stored and freshly generated JVP/VJP also
compile and agree with the hand formulas. FortAD reverse mode deliberately
refuses the active complex adjoint because only real projections are currently
implemented. The runner requires the exact diagnostic and no reverse artifact,
so this is a bounded expected refusal rather than a reverse-support claim.

Run:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_set01_lh016.sh
```

See
[`results/tapenade_set01_lh016_refusal_validation.txt`](../../results/tapenade_set01_lh016_refusal_validation.txt).
