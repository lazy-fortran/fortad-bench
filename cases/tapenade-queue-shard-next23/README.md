# Tapenade Fortran modern-feature queue shard: next23

Next23 closes exactly four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows from the post-next22 queue. The
fixed modern-feature score is ordered descending, with committed queue order
breaking ties:

| row | score | features | observed boundary |
|---|---:|---|---|
| `set04/v035` (`ffun`) | 47 | `allocatable=1; dimension=11` | module-level allocatable mutable state is refused |
| `set03/cm35` (`top`) | 44 | `pointer=2; type(=2` | TARGET/pointer storage identity is refused |
| `set03/cmv01` (`top`) | 44 | `pointer=2; type(=2` | parser/forward generated context fails; reverse dependent is ambiguous |
| `set06/v307` (`dnrm2`) | 44 | `pointer=2; optional=1; dimension=4` | emitted FortAD products fail standalone syntax |

The exact pinned Tapenade revision is `e59864c`, and the FortAD executable
revision is `0865038`. Every selected source and stored Tapenade reference is
hashed in `result.json`; compiler-clean status and exact source lists come from
the committed batch evidence. Fresh Tapenade and FortAD parser/forward/reverse
probes are retained, and `oracle.py` independently checks bounded primal,
JVP/VJP, pointer-trace, or refusal-boundary behavior. No oracle repairs module
state, pointer identity, undefined bounds, or reverse dependent selection.

Rebuild the canonical record from fresh probe JSON files with:

```bash
python3 cases/tapenade-queue-shard-next23/record.py \
  --raw /var/tmp/fortad-bench-next23-modern/v035-run1/raw.json \
  --raw /var/tmp/fortad-bench-next23-modern/cm35-run1/raw.json \
  --raw /var/tmp/fortad-bench-next23-modern/cmv01-run1/raw.json \
  --raw /var/tmp/fortad-bench-next23-modern/v307-run1/raw.json
python3 cases/tapenade-queue-shard-next23/test_contract.py
```
