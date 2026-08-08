# Tapenade Fortran modern-feature queue shard: next9

This shard closes four disjoint pure-Fortran, compiler-clean procedure rows:
`set06/v290` (`function`, score 82), `set03/cm33` (`allocatefunc`, 82),
`set03/lh056` (`sub1`, 80), and `set03/cm26` (`top`, 80). They are the next
remaining free-form, no-include-risk rows selected by the fixed
case-insensitive modern-feature score, descending score then queue order, after
excluding every existing queue shard.

Fresh pinned Tapenade parser, forward, and reverse probes pass for all four
roots. FortAD records nested-internal-procedure, module-state, and pointer
association boundaries. The independent Python oracle models the exact
derived-array arithmetic and pointer/ownership state separately; it makes no
derivative-support claim for the refused roots.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next9/record.py \
  --raw /var/tmp/fortad-next9-v290/raw.json \
  --raw /var/tmp/fortad-next9-cm33/raw.json \
  --raw /var/tmp/fortad-next9-lh056/raw.json \
  --raw /var/tmp/fortad-next9-cm26/raw.json
python3 cases/tapenade-queue-shard-next9/test_contract.py
```
