# fortad-bench

Correctness and performance corpus for
**[fortad](https://github.com/lazy-fortran/fortad)**, benchmarked against every
automatic differentiation engine we can build.

fortad's goal is to be **faster than all of them at both build time and runtime,
in every mode**. This repository is where that claim is either demonstrated or
refuted. It holds the workloads, the engine adapters, the measurement harness,
and the committed results.

## Downstream port: fortnum and fortfem against Enzyme

Every operator fortnum and fortfem differentiate, plus Enzyme's own suite,
measured in both modes. **39 measurements, all within 30% of Enzyme, 29 of
them faster than Enzyme.** The slowest is fortfem's polygon edge area
tangent at 1.24x.

![fortad against Enzyme](results/fortad_vs_enzyme.png)

![Absolute cost per input](results/fortad_vs_enzyme_absolute.png)

| Suite | Operators | Worst ratio | Faster than Enzyme |
|---|---|---|---|
| Enzyme's own suite | 5 (reverse) | 0.87x lstm | 5 of 5 |
| fortnum | 8 (both modes) | 1.09x erfsum reverse | 11 of 16 |
| fortfem | 9 (both modes) | 1.24x polygon edge area tangent | 13 of 18 |

Correctness is checked before timing: the harness compares fortad, Enzyme and
fortsym on every kernel and stops on the first disagreement. All three agree
everywhere.

### Read rk4 with care

rk4 reverse at 0.11x is the widest margin in the corpus and the least
representative. The kernel is a *linear* ODE, so its four stages collapse to
`state = a*state + b*z(i)` with `a` and `b` loop-invariant. fortad's affine
analysis proves that and reduces the adjoint to two fused multiply-adds per
step with no tape, where Enzyme differentiates the stages as written and
leaves around thirty-five flops per step. Both return the same gradient.

Make the same ODE nonlinear and the margin goes away: fortad then tapes the
state and recomputes all four stages in reverse, exactly as Enzyme does. The
number measures an advantage on affine recurrences, not on Runge-Kutta.

Regenerate with `scripts/build_{enzyme,fortnum,fortfem}_suite.sh`, then
`python3 scripts/plot_vs_enzyme.py`.

## Why this is a separate repository

`fortad` keeps only what a contributor must run on every change: unit tests and
microbenchmarks that finish in seconds. Everything expensive lives here —
multi-engine builds, LLVM and Enzyme plugin toolchains, Julia and Python
environments, large workloads, and scaling sweeps that take hours.

| | [fortad](https://github.com/lazy-fortran/fortad) | fortad-bench |
|---|---|---|
| Tests that gate every commit | yes | no |
| Microbenchmarks (seconds) | yes | no |
| Cross-engine comparison | no | yes |
| Competing engine toolchains | no | yes |
| Large workloads and scaling sweeps | no | yes |
| Committed measurement records | headline numbers only | full records |
| Correctness oracles | yes, in-tree | yes, cross-engine corroboration |

A change to fortad that claims a performance result cites a run recorded here.
A change here never gates a fortad commit.

## What gets measured

Both metrics, for every engine, in every mode. Neither is a footnote.

**Runtime.** Complete-workload wall clock is primary. Also peak resident memory,
tape or checkpoint bytes, and — for the emitted Fortran — whether the compiler
vectorised the kernel, read from its own vectorisation report.

**Build time.** Wall clock from unmodified sources to a runnable derivative,
split into: toolchain setup (amortised, reported separately), AD transformation,
and compilation. Also generated-code size, and incremental rebuild time after a
one-line change to the primal. An LLVM plugin pass and a cached `.f90` are very
different products here, and the numbers should say so.

**Modes.** forward (JVP) · reverse (VJP) · vector forward · vector reverse ·
forward-over-reverse (HVP) · dense Hessian · sparse-compressed Jacobian ·
sparse-compressed Hessian · higher-order Taylor. A mode an engine does not
support is recorded as unsupported, never as a win by default.

**Scaling.** In active-input count, output count, direction count, and problem
size — because those dimensions are what flip the forward-versus-reverse verdict
and what separate vector mode from repeated scalar mode.

## Engines

Each engine is an adapter under `engines/` that builds a case and reports timings
through the same interface. An engine that cannot build is recorded as absent,
not as a failure of the case.

| Engine | Level | Language | Notes |
|---|---|---|---|
| **fortad** | Fortran AST/IR → Fortran | Fortran | the subject |
| analytical | hand-derived | Fortran | the ceiling, not a competitor |
| finite differences | — | Fortran | accuracy floor and independent oracle |
| Enzyme + flang-new | LLVM IR | Fortran | primary runtime target |
| Enzyme + LFortran | LLVM IR | Fortran | |
| Enzyme + Clang | LLVM IR | C++ | for ported C++ cases such as VMEC++ |
| Tapenade | source transformation | Fortran | primary source-level target |
| Clad | Clang AST → C++ | C++ | AST-level comparison point |
| CoDiPack | expression templates | C++ | fastest overloading tape |
| ADOL-C | tape | C++ | reference semantics, sparse drivers |
| Adept | expression templates | C++ | |
| Sacado | templates | C++ | forward-over-reverse |
| JAX | jaxpr → XLA | Python | |
| PyTorch | tape / dynamo | Python | |
| Enzyme.jl | LLVM IR | Julia | |
| Mooncake.jl | typed SSA | Julia | mutation-heavy reverse mode |
| ForwardDiff.jl | overloading | Julia | chunked vector forward |

Copyleft engines (CoDiPack, Clad, ColPack-dependent drivers) are built and run as
**separate processes or separate builds**. Their numbers enter this repository;
their code does not. See [LEGAL.md](LEGAL.md).

## Cases

Each case under `cases/` fixes the mathematics, the inputs, the outputs, and the
validation criteria, then provides one implementation per engine language. The
problem never changes between engines — only the derivative mechanism does.

Planned, in the order fortad's roadmap needs them:

1. **`vmec-jacobian`** — the VMEC++ half-grid Jacobian kernel. We already have
   measured Enzyme forward and reverse numbers for the C++ version. The Fortran
   port written *idiomatically*, rather than in the allocation-free flat-buffer
   form Enzyme requires, is fortad's go/no-go head-to-head.
2. **`heat1d`** — the fixed 1D heat-equation step from
   [differentiable-fortran](https://github.com/lazy-fortran/differentiable-fortran),
   whose contract and protocol this repository inherits rather than reinvents.
3. **`fortnum-kernels`** — kernels from
   [fortnum](https://github.com/lazy-fortran/fortnum) that already carry an
   `analytical` derivative candidate and committed baselines, so the first
   results are three-way comparisons needing no new infrastructure.
4. **`adbench`** — GMM, bundle adjustment, hand tracking, LSTM. The standard
   cross-tool suite Enzyme's own papers report, ported with attribution (MIT).
5. **`solve-heavy`** — a Newton solve and a fixed-point iteration. Where implicit
   differentiation and Christianson's two-phase adjoint should beat every engine
   that differentiates the iterations. The largest predicted margin.
6. **`sparse`** — Jacobians and Hessians with exploitable structure.
7. **`scaling`** — synthetic sweeps in input, output, and direction count.

## The study corpus

This repository also holds the field survey that fortad's design rests on,
because it belongs next to the engines rather than next to the compiler.

- **[`docs/upstreams.toml`](docs/upstreams.toml)** — 39 third-party AD projects,
  pinned with licence, the paths worth reading, and what we want to learn from
  each. `scripts/fetch_upstreams.py` clones them into a gitignored `upstream/`
  tree and verifies every declared licence against the actual checkout.
- **[`docs/reading-list.md`](docs/reading-list.md)** — the literature, curated by
  hand and tiered by reading order, with checked DOIs and arXiv links, marking
  which items are freely available and which need institutional access.
- **[`docs/bibliography.bib`](docs/bibliography.bib)** — the same works as BibTeX
  for citation and Zotero import.

Metadata is committed. Checkouts and full text are not.

## Layout

```
cases/      one directory per workload: statement, reference data, per-language sources
engines/    one adapter per AD engine: build, run, report
harness/    timing, memory, vectorisation-report parsing, result schema
results/    committed measurement records, one file per (machine, date, run)
scripts/    fetch_upstreams.py, environment setup, sweep drivers, plotting
docs/       upstreams manifest, reading list, method
upstream/   gitignored: third-party study checkouts
literature/ gitignored: locally held papers
```

## Rules for a number to count

1. The derivative passed an **independent oracle** first — hand-derived
   analytical, finite differences with a convergence test, the adjoint identity
   `⟨u, Jv⟩ = ⟨Jᵀu, v⟩`, or [fortsym](https://github.com/lazy-fortran/fortsym).
   Agreement between two AD engines is corroboration, never the oracle.
2. Machine, OS, compiler and version, engine revision, flags, and measurement
   method are recorded in the result file. A number without them is discarded.
3. Build time and runtime are reported together. A runtime win reported without
   its build cost is incomplete.
4. Every engine gets its best honest configuration. Losing to a badly configured
   competitor proves nothing, and a benchmark that flatters fortad is worse than
   no benchmark.
5. Committed results are records of what happened on one machine, not promises
   about another.

## Status

Scaffolding. No cases, adapters, or results yet. The first deliverable is
`cases/vmec-jacobian` with the analytical, Enzyme, and finite-difference
engines, so that fortad has a number to beat before it has an implementation.

## Licence

MIT. See [LICENSE](LICENSE). Ported workloads carry their upstream copyright
notice and a [PROVENANCE.md](PROVENANCE.md) row.
