# Tapenade Fortran modern-feature queue shard: next44

Next44 closes four previously unclassified, pure-Fortran, compiler-clean,
dependency-safe procedure leaders after next43. Selection uses the fixed
case-insensitive modern-feature score, descending score, then committed queue
order for ties. The MPI program row is retained because its `msg1` procedure
is a callable root; its local `mpif.h` is recorded as a dependency hint, not
silently treated as a derivative-support result.

| row | root | score | features | observed FortAD boundary |
|---|---|---:|---|---|
| `set06/v315` | `msg1` | 22 | `final=1; dimension=5` | MPI_ISEND has no derivative rule; reverse has no inferred dependent |
| `set03/lh087` | `cross_prod` | 15 | `dimension=5` | vector-subscript section storage identity is not tracked |
| `set11/html01` | `barf` | 15 | `bind(c)=2; iso_c_binding=1` | BIND(C)/COMMON parsing boundary |
| `set03/bd09` | `head` | 14 | `pointer=1` | exact source reallocates `cindex` before deallocation |

Fresh pinned Tapenade parser, forward, and reverse products pass for all four
exact roots. FortAD records the measured refusal for each mode. `bd09` is an
invalid-upstream closure: strict syntax acceptance does not make its runtime
allocation sequence valid, since `cindex` is allocated twice. The other three
rows are actionable FortAD support boundaries, not upstream invalidity.

The independent oracle models only the bounded behavior needed to classify the
boundary: an MPI payload identity, a three-vector cross product, the scalar
state recurrence behind `barf`, and the invalid allocation state machine. It
checks hand derivatives against finite differences where a valid numeric model
exists, and makes no exact-source derivative-support claim for a refused
transformation.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next44/record.py \
  --raw /var/tmp/fortad-bench-next44-v315/raw.json \
  --raw /var/tmp/fortad-bench-next44-lh087/raw.json \
  --raw /var/tmp/fortad-bench-next44-html01/raw.json \
  --raw /var/tmp/fortad-bench-next44-bd09/raw.json
python3 cases/tapenade-queue-shard-next44/test_contract.py
```
