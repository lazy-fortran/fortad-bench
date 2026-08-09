# Tapenade Fortran modern-feature queue shard: next47

Next47 closes exactly four previously unclassified, pure-Fortran,
compiler-clean, dependency-safe, free-form procedure candidates after
next46. Selection uses the fixed case-insensitive modern-feature score,
descending score, then committed queue order for ties. The three higher-scoring
program-only rows remain queued because the contract requires a callable
procedure root.

| row | root | score | feature | measured FortAD boundary |
|---|---|---:|---|---|
| `set03/cm27` | `top` | 14 | `pointer=1` | pointer-association storage identity |
| `set03/cm28` | `top` | 14 | `pointer=1` | pointer-association storage identity |
| `set03/lh052` | `sub` | 14 | `pointer=1` | TARGET alias storage identity |
| `set05/v118` | `foo` | 14 | `pointer=1` | pointer-association storage identity |

Fresh automatic-fetch provenance at pinned Tapenade `e59864c…` passes parser,
forward, and reverse for every exact root. Current FortAD `f47d42e…` refuses
all three modes for every root before derivative output because pointer/TARGET
storage identity is not tracked. The independent Python oracle checks the
defined pointer branches, the two-target quadratic update, and the pointer
graph; it deliberately makes no numeric claim for `cm27` or `v118`, whose exact
sources define pointer state rather than a numeric output contract.

`result.json` retains exact source/reference SHA-256 hashes, pinned upstream
and FortAD revisions, compiler evidence, commands and diagnostics, generated
source syntax checks, and independent oracle output. Rebuild and check it with:

```bash
python3 cases/tapenade-queue-shard-next47/record.py \
  --raw /var/tmp/fortad-bench-next47-cm27.json \
  --raw /var/tmp/fortad-bench-next47-cm28.json \
  --raw /var/tmp/fortad-bench-next47-lh052.json \
  --raw /var/tmp/fortad-bench-next47-v118.json
python3 cases/tapenade-queue-shard-next47/test_contract.py
```
