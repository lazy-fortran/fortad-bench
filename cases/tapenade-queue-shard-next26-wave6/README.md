# Tapenade Fortran modern-feature queue shard: next26 wave6

This shard closes the next four previously unclassified pure-Fortran rows after
next25. Selection requires free-form syntax, compiler-clean batch evidence, no
unresolved dependency risk, and a real procedure in the exact primary source.
The fixed modern-feature score is ordered descending, with committed queue
order breaking ties:

| row | root | score | features | measured boundary |
|---|---|---:|---|---|
| `set04/lh113` | `foo` | 42 | `allocatable=1; type(=1; interface=1; dimension=5` | module-level allocatable mutable state |
| `set11/ompl07` | `stencil_nodefault` | 39 | `dimension=13` | OpenMP directive |
| `set05/v179` | `flio_uga` | 37 | `optional=7; dimension=3` | unsupported WRITE statement; no numeric map claimed |
| `set06/v341` | `top` | 34 | `allocatable=1; type(=1; dimension=4` | unallocated allocatable derived component |

The exact pinned Tapenade revision is `e59864c`. The measured FortAD binary is
revision `f878b96`; its refusal diagnostics are retained in `result.json`.
Tapenade emits parser, forward, and reverse products for all four roots. The
independent Python oracles check bounded primal/JVP behavior where defined and
explicitly avoid claiming transformation support for the refusal boundaries.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
engine commands and diagnostics, generated-source checks, revision pins, and
the independent oracle results. Rebuild it from the retained probe records with:

```bash
python3 cases/tapenade-queue-shard-next26-wave6/record.py \
  --raw /var/tmp/fortad-bench-next26-wave6-lh113.raw.json \
  --raw /var/tmp/fortad-bench-next26-wave6-ompl07.raw.json \
  --raw /var/tmp/fortad-bench-next26-wave6-v179.raw.json \
  --raw /var/tmp/fortad-bench-next26-wave6-v341.raw.json
python3 cases/tapenade-queue-shard-next26-wave6/test_contract.py
```

The queue and audit commands remain:

```bash
python3 scripts/fetch_upstreams.py --audit-pins
python3 scripts/fetch_upstreams.py --audit-corpora
python3 scripts/queue_tapenade_fortran.py --check
```
