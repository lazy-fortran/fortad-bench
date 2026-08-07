# Tapenade set12 modern tranche A

This tranche deliberately covers two different product boundaries. `cmplxstep01`
is a negative design case: its active result depends on mutable module state and
active components of a global derived object. FortAD should diagnose that
boundary instead of silently differentiating hidden state. `f03typf01` exercises
an abstract deferred binding and `f03fptr01` exercises an abstract procedure
interface with procedure-pointer dispatch. Their independent oracles validate the child-specific
primal maps and directional/adjoint derivatives, even though the current FortAD
front end refuses the polymorphic call sites.

The runner reads the exact pinned upstream sources, invokes fresh Tapenade parser,
forward, and reverse generation, and records source/generated compile statuses.
Run it with:

```sh
scripts/bench_tapenade_set12_modern_tranche_a.sh
```

The result is stored in
`results/tapenade_set12_modern_tranche_a_validation.txt`. No corpus ledger rows
are changed by this tranche.
