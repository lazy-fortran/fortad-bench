# Tapenade Fortran modern-feature queue shard: next15

This shard closes exactly four disjoint pure-Fortran, compiler-clean,
dependency-free candidates selected from the current queue by the committed
modern-feature score, descending score then queue order. The deterministic
selection is `set05/v077` (101), `set11/vpf20` (92), `set10/lh230` (88), and
`set10/lh232` (88). The final tie is resolved by the queue order. The cases
cover overloaded operators, nested derived-type arithmetic, and two pointer
components stored in COMMON/SAVE state.

Fresh probes use Tapenade revision `e59864c` and the FortAD executable revision
recorded in `result.json`. Exact primary/reference sources pass strict and
legacy compiler checks. Tapenade generates parser/forward/reverse products for
all four roots. FortAD produces a valid parser product for `v077` but its
numeric logical derivative products fail strict generated-source compilation;
`vpf20` reaches the explicit derived-object boundary; and the two COMMON/SAVE
pointer cases refuse at the explicit pointer-storage boundary. These are
evidence-backed classifications, not vague transformation failures.

The independent oracle models the operator truth table, nested component
arithmetic, and pointer-backed storage updates. It makes no derivative-support
claim for the refusal or nonnumeric logical cases.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next15/record.py \
  --raw /var/tmp/fortad-bench-next15-set05-v077/raw.json \
  --raw /var/tmp/fortad-bench-next15-set11-vpf20/raw.json \
  --raw /var/tmp/fortad-bench-next15-set10-lh230/raw.json \
  --raw /var/tmp/fortad-bench-next15-set10-lh232/raw.json
python3 cases/tapenade-queue-shard-next15/test_contract.py
```
