# Tapenade Fortran modern-feature queue shard: next25

Next25 closes exactly four previously unclassified pure-Fortran rows after
next24. The selection requires free-form syntax, compiler-clean batch evidence,
no unresolved include risk, and a real procedure entry point in the exact
primary source. The fixed modern-feature score is ordered descending, with
committed queue order breaking ties:

| row | root | score | features | observed boundary |
|---|---|---:|---|---|
| `set06/v346` | `bar` | 63 | `pointer=2; procedure=2; interface=2; dimension=3` | pointer association storage identity |
| `set07/v397` | `head` | 55 | `pointer=1; procedure=2; interface=5` | generic call derivative rule |
| `set11/vpf15` | `foo` | 47 | `type(=3; procedure=1; interface=3` | reverse generated derived-type module context |
| `set03/cm23` | `top` | 42 | `allocatable=3` | allocatable storage across helper calls |

The numerically higher `set03/cm08` row was deliberately not selected: its
exact primary source contains only a program and no differentiable procedure
root. This preserves the established real-entry requirement for fresh probes.

The exact pinned Tapenade revision is `e59864c`. Probes use FortAD revision
`0a5143a`. Tapenade emits parser, forward, and reverse products for all four
roots. FortAD refuses the three ownership/call-boundary cases. For `vpf15`,
FortAD parser and forward products pass strict syntax, while the reverse product
loses the derived-type module context and fails standalone syntax. The
independent Python oracle checks concrete bounded maps, finite-difference JVPs
or analytical VJPs where defined, and the allocation/alias traces without
repairing undefined state or claiming support for pointer identity.

Rebuild the canonical record from the retained probe JSON files with:

```bash
python3 cases/tapenade-queue-shard-next25/record.py \
  --raw /var/tmp/fortad-bench-next25-v346.raw.json \
  --raw /var/tmp/fortad-bench-next25-v397.raw.json \
  --raw /var/tmp/fortad-bench-next25-vpf15.raw.json \
  --raw /var/tmp/fortad-bench-next25-cm23.raw.json
python3 cases/tapenade-queue-shard-next25/test_contract.py
```

The automatic fetch and audit path remains:

```bash
python3 scripts/fetch_upstreams.py --corpus tapenade
python3 scripts/fetch_upstreams.py --audit-pins
python3 scripts/fetch_upstreams.py --audit-corpora
python3 scripts/queue_tapenade_fortran.py --check
```

The fetch and audit commands use the immutable Tapenade revision in
`docs/upstreams.toml`. The queue command consumes only the committed static
triage and status ledger, so regenerating it after this shard is deterministic.
