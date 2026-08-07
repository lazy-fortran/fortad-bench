# Tapenade corpus

Fetch and verify the pinned checkout:

```bash
scripts/fetch_upstreams.py --corpus tapenade
```

The command checks out Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9`, verifies its Git tree and all
10,977 tracked paths, then writes `docs/generated/tapenade-corpus.md`. Both the
checkout and generated inventory are gitignored. Repeat the audit without a
network request with:

```bash
scripts/fetch_upstreams.py --audit-corpora
```

## Inventory

The six checked-in Tapenade corpus roots contain:

| root | tracked files | candidate cases | contents |
|---|---:|---:|---|
| `nonRegressions` | 9,707 | 1,906 | regression inputs, expected derivatives and messages, options, harness, data |
| `examples` | 256 | 25 | large examples, expected output, harness |
| `examplesF77` | 9 | 0 | legacy harness; no case directory at this revision |
| `examplesC` | 111 | 6 | C reference cases and harness |
| `examplesCPP` | 7 | 6 | standalone C++ parser examples |
| `openmp` | 89 | 9 | OpenMP examples, runtime code, diagrams, scripts, data |

The manifest also records 52 known-failure cases under `todoC` and `todoF90`,
the ADMM test, three FirstAidKit runtime tests, six Julia parser examples, and
the support declarations in `resources/lib`. Those entries add 62 candidates.
The combined inventory contains 10,513 tracked files and 2,014 candidates. See
[`corpora/tapenade.toml`](corpora/tapenade.toml) for the exact paths and counts.

A candidate is a unit to classify. Some entries are runnable programs. Others
are expected output, parser fixtures, support files, or historical failures.
The inventory does not claim that FortAD currently differentiates any new
case.

## Closeout rule

Every candidate gets a committed status row with its language, source form,
entry point, Tapenade options, derivative modes, oracle, dependencies, and
FortAD result. A runnable numerical case also gets transformation time, compile
time, runtime, peak memory, and generated-source size for each applicable
engine.

Fortran cases close only after all valid differentiable paths work in FortAD
and pass an independent oracle. Invalid programs and cases that require an
unavailable external library get a reproducible classification. C, C++, and
Julia inputs remain in the ledger so cross-engine coverage cannot omit them or
count them as FortAD wins.

Tapenade is MIT-licensed at the pinned revision. The checkout remains upstream
material. Any port committed under `cases/` must retain the upstream notice and
add a row to [`../PROVENANCE.md`](../PROVENANCE.md).
