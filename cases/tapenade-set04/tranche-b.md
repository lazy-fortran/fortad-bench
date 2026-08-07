# Tapenade set04 tranche B: `lh128`, `lh151`, and `lh152`

This tranche closes three dependency-free, previously untriaged Fortran queue
entries from the exact pinned `nonRegressions/set04` checkout. The runner reads
the upstream `program.f90` files directly; it does not replace them with a
repaired port. It also hashes each selected upstream source and stored
reference in the result, so the Tapenade provenance remains explicit.

`lh152` passes both FortAD modes and the independent numerical harness.
`lh151` passes the forward transform and records a stable reverse-mode refusal
at the loop boundary. `lh128` passes forward mode; its reverse output is
generated but the independent compiler oracle refuses it because FortAD emits
duplicate `w_b` dummy arguments. These are recorded as expected boundaries,
not as reverse-support claims.

Run the complete evidence check with:

```sh
scripts/bench_tapenade_set04_tranche_b.sh
```

The pinned result is recorded in
`results/tapenade_set04_tranche_b_validation.txt`.
