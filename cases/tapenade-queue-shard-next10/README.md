# Tapenade Fortran modern-feature queue shard: next10

This shard closes the next four disjoint pure-Fortran, compiler-clean,
free-form procedure rows after excluding every existing queue shard. The fixed
case-insensitive modern-feature score selects `set06/v285` (`mainsub`, 77),
`set04/lh176` (`getcrn_all`, 76), and the tied `set03/cmv02` and `set03/cmv03`
(`top`, 74 each), in committed queue order.

Fresh pinned Tapenade parser, forward, and reverse products are recorded. The
exact FortAD boundary is explicit: `v285` refuses module-level allocatable
mutable state and `lh176` refuses pointer-association storage identity. The two
tree-component rows emit products at the command boundary; this is not a
runtime or derivative-support claim. The independent oracle checks the exact
tree arithmetic and pointer-assignment primal semantics separately.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next10/record.py \
  --raw /var/tmp/fortad-next10-v285/raw.json \
  --raw /var/tmp/fortad-next10-lh176/raw.json \
  --raw /var/tmp/fortad-next10-cmv02/raw.json \
  --raw /var/tmp/fortad-next10-cmv03/raw.json
python3 cases/tapenade-queue-shard-next10/test_contract.py
```
