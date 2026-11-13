# User guide

Start with the [repository README](../README.md) for requirements and a corpus
audit. Use the [benchmark guide](benchmarks.md) to choose a workload and find its
build script, correctness checks and recorded results.

## Components

| Directory | Purpose |
| --- | --- |
| `cases/` | primal workloads, reference derivatives and independent oracles |
| `harness/` | Fortran drivers for correctness, timing and scaling |
| `engines/` | interfaces used when building external differentiation tools |
| `scripts/` | source fetching, corpus classification, builds and plots |
| `results/` | recorded measurements and toolchain information |
| `cases/tapenade-exact/` | exact-source probe contracts, oracles and preserved inventories |

The [Tapenade guide](tapenade-corpus.md) explains the distinction between source
validity, parser acceptance, generated-code compilation and derivative checks.
The [size-sweep guide](enzyme-suite-size-sweep.md) explains the controlled
Enzyme-inspired workloads. [PROVENANCE.md](../PROVENANCE.md) identifies reused
sources and their licences.

## Reproducing a result

Use the workload's recorded engine revision, compiler and flags. Select the
fortad checkout with `FORTAD_REPO` when the script requests it. Source-generation,
compilation and runtime are separate measurements; preserve all of them when
comparing tools. A historical result does not become a measurement of a newer
compiler or derivative engine merely because the harness still builds.

Run `python3 -m unittest discover -s scripts -p 'test_*.py'` for the script tests.
Exact-source contracts also use the pinned Tapenade checkout fetched by
`scripts/fetch_upstreams.py --corpus tapenade`. Full benchmark runs may require
additional compilers or external tools; their absence is a verification limit.
