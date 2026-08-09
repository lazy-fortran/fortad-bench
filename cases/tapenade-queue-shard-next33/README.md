# Tapenade Fortran modern-feature queue shard: next33

Next33 closes the next four disjoint pure-Fortran, compiler-clean,
dependency-safe, free-form procedure rows after next32. They are ordered by
the fixed modern-feature score, descending score and then committed queue
order:

| row | root | score | features | exact FortAD boundary |
|---|---|---:|---|---|
| `set11/mvo02` | `foo` | 20 | `interface=4` | exact actual/formal mapping for a same-file call |
| `set07/v460` | `top` | 19 | `interface=2; dimension=3` | local interface statement at line 12 |
| `set04/v031` | `head` | 18 | `procedure=1; interface=2` | no derivative rule for generic `swap` |
| `set05/v148` | `p` | 18 | `interface=2; optional=2` | reverse dependent inference |

The exact pinned Tapenade revision is `e59864c`; probes use the current
FortAD executable at revision `e347c8a`. Tapenade parser, forward, and reverse
probes pass for all four exact roots. FortAD records the observed parser,
forward, or reverse boundaries; `mvo02` and `v031` are explicit generic/call
boundaries, `v460` is a local-interface boundary, and `v148` is a reverse
dependent-inference boundary. None is classified as invalid upstream. The
independent oracles check either a bounded numerical map or the exact dispatch
and optional-argument boundary and make no derivative-support claim for a
refused mode.

`result.json` retains exact source/reference SHA-256 hashes, compiler evidence,
probe commands and diagnostics, revision pins, generated-source syntax checks,
and independent behavioral/refusal-oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next33/record.py \
  --raw /var/tmp/fortad-bench-next33-mvo02-run1/raw.json \
  --raw /var/tmp/fortad-bench-next33-v460-run1/raw.json \
  --raw /var/tmp/fortad-bench-next33-v031-run1/raw.json \
  --raw /var/tmp/fortad-bench-next33-v148-run1/raw.json
python3 cases/tapenade-queue-shard-next33/test_contract.py
```
