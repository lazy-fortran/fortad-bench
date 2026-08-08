# Tapenade Fortran modern-feature queue shard: next5

This shard closes four disjoint pure-Fortran, compiler-clean queue rows:
`set11/v540a` (`testallocs`, score 159), `set11/v541a` (`testallocs`, 159),
`set06/v339` (`test`, 88), and `set05/v197` (`testblockfun`, 30).
They are exact source roots not used by the next, next2, next3, or next4
shards, selected from the branch-base queue by the committed modern-feature
score.

The rows cover allocatable/TARGET work arrays, recursive pointer components,
derived-type allocatable components, and a second allocatable procedure
closure. Fresh pinned Tapenade parser, forward, and reverse probes pass for
every root. FortAD records the exact refusal boundary for each root; the
independent Python models pass without making a derivative-support claim.
Every source and reference is strict-compiled and hash-recorded in
`result.json`.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next5/record.py \
  --raw /var/tmp/fortad-bench-next5-v540a/raw.json \
  --raw /var/tmp/fortad-bench-next5-v339/raw.json \
  --raw /var/tmp/fortad-bench-next5-v197/raw.json \
  --raw /var/tmp/fortad-bench-next5-v541a/raw.json
python3 cases/tapenade-queue-shard-next5/test_contract.py
```
