# Tapenade Fortran modern-feature queue shard: next24

Next24 closes exactly four previously unclassified pure-Fortran rows after
next23. The selection requires free-form syntax, compiler-clean batch evidence,
no unresolved include risk, and a real procedure entry point in the exact
primary source. The fixed modern-feature score is ordered descending, with
committed queue order breaking ties:

| row | score | features | observed boundary |
|---|---:|---|---|
| `set07/v398` (`head`) | 88 | `pointer=2; type(=6; dimension=4` | generated module context and reverse dependent inference |
| `set07/v529` (`compute`) | 75 | `allocatable=3; interface=3; dimension=6` | module-level mutable state |
| `set04/lh142` (`head`) | 73 | `allocatable=3; type(=2; dimension=5` | module-level allocatable state |
| `set11/vpf21` (`foo`) | 73 | `type(=4; procedure=2; interface=5` | reverse generated derived-type module context |

The exact pinned Tapenade revision is `e59864c`. Probes use FortAD revision
`e9a6186`. Tapenade emits parser, forward, and reverse products for all four
source procedures. FortAD records product-generation and refusal boundaries in
`result.json`. The independent Python oracle uses explicit local values and
checks a primal map plus finite-difference JVP or analytical VJP. It does not
repair module state, pointer ownership, undefined allocation contents, or lost
derived-type context.

The queue and batch hashes in `manifest.toml` bind selection to the branch base
and the post-shard queue. Rebuild the canonical record from the retained probe
JSON files with:

```bash
python3 cases/tapenade-queue-shard-next24/record.py \
  --raw /var/tmp/fortad-bench-next24-v398.uN3evO/raw.json \
  --raw /var/tmp/fortad-bench-next24-v529.jo4Qot/raw.json \
  --raw /var/tmp/fortad-bench-next24-lh142.jmJg8k/raw.json \
  --raw /var/tmp/fortad-bench-next24-vpf21.uoLBdb/raw.json
python3 cases/tapenade-queue-shard-next24/test_contract.py
```

The automatic path remains:

```bash
python3 scripts/fetch_upstreams.py --corpus tapenade
python3 scripts/fetch_upstreams.py --audit-pins
python3 scripts/fetch_upstreams.py --audit-corpora
python3 scripts/queue_tapenade_fortran.py --check
```

The fetch and audit commands use the immutable Tapenade revision in
`docs/upstreams.toml`. The queue command consumes only the committed static
triage and status ledger, so regenerating it after this shard is deterministic.
