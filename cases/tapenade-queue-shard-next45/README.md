# Tapenade Fortran modern-feature queue shard: next45

Next45 closes four previously unclassified, pure-Fortran, compiler-clean,
dependency-safe free-form procedure candidates after next44. They are a
focused pointer-alias lane: each exact source uses pointer association or
reassociation, and `v338` additionally uses module-level mutable pointer
state. Selection uses the fixed case-insensitive modern-feature score,
descending score, then committed queue order for ties.

| row | root | score | feature | observed FortAD boundary |
|---|---|---:|---|---|
| `set03/cm01` | `program` | 14 | `pointer=1` | conditional `p1`/`p2` storage identity |
| `set03/cm02` | `program` | 14 | `pointer=1` | allocate/reassociate/deallocate storage identity |
| `set03/cm03` | `program` | 14 | `pointer=1` | conditional `p1`/`p4` storage identity |
| `set06/v338` | `test` | 14 | `pointer=1` | TARGET/module-pointer storage identity |

Fresh pinned Tapenade parser, forward, and reverse products pass for all four
exact roots. FortAD refuses all three modes at its pointer storage-identity
boundary. These are valid upstream cases and actionable FortAD support
boundaries, not invalid-source closures. The `v338` source is also a deliberate
global mutable-state pattern; even after pointer identity support, that pattern
remains outside the approved FortAD policy.

The independent oracles model only bounded behavior: the valid `v4=1` branch
of `cm01`, the payload before `cm02` alias cleanup, the constant `v2=1` branch
of `cm03`, and the explicit `x**4` recurrence of `v338`. They check hand
derivatives against finite differences where a scalar model is defined, read no
Tapenade or FortAD output, and make no exact-source derivative-support claim.

`result.json` retains exact source/reference SHA-256 hashes, automatic-fetch
revision provenance, compiler evidence, parser/forward/reverse commands and
diagnostics, generated-source syntax checks, revision pins, and independent
oracle output. Rebuild it with:

```bash
python3 cases/tapenade-queue-shard-next45/record.py \
  --raw /var/tmp/fortad-bench-next45-cm01/raw.json \
  --raw /var/tmp/fortad-bench-next45-cm02/raw.json \
  --raw /var/tmp/fortad-bench-next45-cm03/raw.json \
  --raw /var/tmp/fortad-bench-next45-v338/raw.json
python3 cases/tapenade-queue-shard-next45/test_contract.py
```
