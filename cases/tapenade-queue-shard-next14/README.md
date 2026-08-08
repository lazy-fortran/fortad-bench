# Tapenade Fortran modern-feature queue shard: next14

This shard closes exactly four disjoint pure-Fortran, compiler-clean,
dependency-free candidates selected from the branch-base queue. The fixed
modern-feature score ranks `set04/v004` (50), `set07/v531` (48), `set04/lh108`
(47), and `set04/v048` (32). The selection intentionally favors varied
modern/pure features over another global-`SAVE`-heavy row.

The cases cover overloaded derived-type arithmetic, pointer-bearing derived
arrays, allocatable components with pointer association, and an elemental
generic interface. Tapenade parser/forward/reverse probes are pinned to
`e59864c`; FortAD probes are pinned to `db4259e`. Exact source and reference
hashes, strict and legacy compiler checks, generated-source syntax checks, and
independent primal/refusal or affine JVP/VJP oracles are recorded in
`result.json`. No case is marked invalid-upstream.

Rebuild and check with:

```bash
python3 cases/tapenade-queue-shard-next14/record.py \
  --raw /var/tmp/fortad-next14-v004-run1/raw.json \
  --raw /var/tmp/fortad-next14-v531-run1/raw.json \
  --raw /var/tmp/fortad-next14-lh108-run1/raw.json \
  --raw /var/tmp/fortad-next14-v048-twice-run1/raw.json
python3 cases/tapenade-queue-shard-next14/test_contract.py
```
