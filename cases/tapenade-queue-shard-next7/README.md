# Tapenade Fortran modern-feature queue shard: next7

This shard closes four disjoint pure-Fortran, compiler-clean procedure rows:
`set03/cm07` (`top`, score 96), `set04/v006` (`head`, 94), `set11/v006`
(`head`, 94), and `set03/cm09` (`top`, 90). They are the next rows selected
from the branch-base queue by the fixed modern-feature score, descending score
then queue order, after excluding every existing queue shard. Each selected
entry point is declared in its exact primary source.

The exact sources are strict-compiled and legacy-compiled, and fresh pinned
Tapenade parser, forward, and reverse probes pass for all four roots. FortAD
records pointer-storage-identity refusals for `cm07` and `cm09`; for both
`v006` roots its parser command emits a product whose strict compile refuses
the generated `TF_1_` interface, while forward and reverse refuse the active
derived-object component boundary. The independent oracle models the pointer
alias/refusal boundaries and verifies the overloaded-derived-type `v006`
primal, hand JVP, central difference, and adjoint dot product. No derivative
support claim is made for any row.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next7/record.py \
  --raw /var/tmp/fortad-bench-next7-set03-cm07-*/raw.json \
  --raw /var/tmp/fortad-bench-next7-set04-v006-*/raw.json \
  --raw /var/tmp/fortad-bench-next7-set11-v006-*/raw.json \
  --raw /var/tmp/fortad-bench-next7-set03-cm09-*/raw.json
python3 cases/tapenade-queue-shard-next7/test_contract.py
```
