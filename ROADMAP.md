# fortad-bench roadmap

This repository is where fortad's performance claim is demonstrated or
refuted. It holds the workloads, the engine adapters, the harness, and the
committed results. `README.md` reports the current numbers. This file tracks
what is missing from them.

## Status, 2026-08-07

Coverage stands at 59 downstream operators: 17 in the fortnum suite and 42 in
the fortfem suite. A separate Enzyme-native suite contributes five additional
operators, reported outside that 59-operator cross-engine total.
Every operator that both Enzyme and fortad can differentiate has numbers
recorded. Nearly all measurements sit within the 30% band agreed for the port.
The exceptions are named below.

This is not yet a claim to beat every AD engine. The committed same-machine
timing table is FortAD versus Enzyme. The pinned Tapenade corpus has nine
set01 evidence rows (seven positive cases and two reproducible refusals), with
1,497 candidates still untriaged. A broader feature or performance lead needs
the remaining corpus classifications and the end-to-end itpplasma matrix below.

The fortfem catalogue has 44 names. The checkout currently contains 43 primal
kernel sources (plus their C-bound copies). The harness runs 42 of them.
`cartesian_to_toroidal` is intentionally omitted because Enzyme has no rule for
`atan2`, while `toroidal_point_to_cartesian` has no generated source in this
checkout. Add the missing source or remove that catalogue entry before claiming
complete catalogue coverage.

## Outstanding

### Re-measure the vector-Newton routines (done 2026-08-05)

Three of fortnum's vector-Newton routines were absent from the corpus
because fortad could not differentiate them: `hoist_subexpressions` did not
terminate on a body with several inlined callees. That defect is fixed. The
routines are now measured in a focused fortad record at
`results/vector_newton_fortad.csv`, and they are the last of Enzyme's fortnum
corpus that fortad could not cover for a fortad-owned reason. The record is
not added to the 59-operator cross-engine table because acluster has no
compatible Enzyme toolchain. It therefore makes no same-machine 30% claim.

P1.9's second and third kernel closeout is recorded in
`results/p19_kernels_fortad.csv` and `results/p19_kernels_validation.txt`:
`erfsum` from `special/` and `fixed_quadrature_integrand` from `quadrature/`.
The existing 59-operator cross-engine table already contains both. The
quadrature kernel's zero-loop vectorisation report is retained as the known
slice-packing limitation rather than being presented as a win.

### Three caveats in the committed results

All three are recorded in `README.md` and none is resolved:

- `rk4` reverse at 0.11x is the widest margin in the corpus and the least
  representative. The kernel is a linear ODE, so its stages collapse to an
  affine recurrence and fortad's analysis reduces the adjoint to two fused
  multiply-adds per step with no tape. The transformation is general rather
  than fitted to this kernel, but the margin should not be quoted as
  typical, and Tapenade is the engine that would confirm it.
- `adaptive_trace_integrand` tangent at 1.69x is the one fortnum
  measurement outside 30%, and the derivative is not the reason: fortad
  emits the minimal form and compiles to 68 instructions against Enzyme's
  119, and is still slower. This is a code-generation question for the
  compiler, not a fortad rule, and it is
  unresolved.
- fortfem's curved quadrilateral cell area tangent at 1.63x is the widest
  gap in that suite, caused by slice packing paying twice on a wide
  operator. Diagnosed in the fortad roadmap. Unfixed.

### Tapenade

Tapenade is the third engine of interest. It is the only other one that does
the affine-recurrence collapse through its to-be-recorded analysis, which
makes it the honest comparison for the `rk4` reverse result. Corpus support is
now wired into the harness for seven small set01 cases, with two exact-source
refusals. A fresh Tapenade
engine run and the rest of the corpus remain open.

The complete tracked checkout is now reproducible. The
[`corpus manifest`](docs/corpora/tapenade.toml) pins commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and tree
`17288bdf7e03cb23b82ddc769d884deed9c9575e`. It verifies 10,977 tracked files
and inventories 2,014 candidate cases without claiming that they run in
FortAD. Completion requires each candidate to be classified, transformed or
explicitly refused, independently checked, and measured when runnable.

- [x] Fetch the pinned source and corpus with
  `scripts/fetch_upstreams.py --corpus tapenade`. Keep both the checkout and
  generated inventory out of Git.
- [x] Commit a deterministic status-ledger scaffold for all 2,014 candidates.
  The offline corpus audit checks each component, path, language hint, and
  source-form hint against the pinned Git tree. All workflow fields start as
  `untriaged` or `not-run`, so this closes inventory infrastructure only.
- [x] Commit static triage for all 2,014 candidates. The generated JSONL records
  6,078 tracked source files plus syntactic entry-point, include, and module
  dependency hints. Its classifications are discovery aids, not parse, build,
  transformation, or correctness results.
- [x] Close the FortAD language boundary for 508 rows with
  `scripts/classify_tapenade_nonfortran.py`. The static report identifies 506
  C, C++, CUDA, or Julia candidates and two candidates with no recognized
  source. Their ledger rows record no FortAD run and no Tapenade run. The 74
  mixed-language candidates and all untested Fortran candidates stay untriaged.
- [x] Build the evidence-neutral next-tranche queue with
  `scripts/queue_tapenade_fortran.py`. Its machine-readable rows and summary
  partition the 1,497 remaining candidates into 74 mixed-language-risk, 37
  historical-failure, 20 no-entry-point, 320 program, and 1,046 procedure
  candidates. An orthogonal missing-dependency-risk signal covers 174 rows
  with non-local include hints. Include targets are dependency-risk signals
  only. This queue does not claim that any source parses or builds.
- [x] Promote the first three runnable numerical cases: [`lh023`, `lh032`, and
  `lh134`](cases/tapenade-set01/README.md). Their [manifest](cases/tapenade-set01/manifest.toml)
  fixes the entry points and mathematics. The [measurement record](results/tapenade_set01_support_validation.txt)
  shows successful forward/reverse transformation, generated-code compilation,
  hand derivatives, four-step finite differences, and adjoint identities.
- [x] Promote `lh088` through the focused tranche-A runner. The retained
  `sqrt`/`log`/power chain passes FortAD forward and reverse compilation,
  hand derivatives, finite-difference convergence, and the adjoint identity.
  see [its result](results/tapenade_set01_tranche_a_validation.txt).
- [x] Record the exact `lh066` in-place reverse boundary. FortAD emits a
  duplicate `a_b` dummy when the mutated dependent is also independent, and
  the independent Fortran compiler rejects the generated file. This is an
  expected refusal in [the refusal record](results/tapenade_set01_refusals.txt),
  not a support claim.
- [x] Promote `lh058` through the focused tranche-C runner. Its Euclidean-norm
  JVP/VJP passes the hand oracle, four-step finite-difference sweep, and
  adjoint identity. All five unmodified upstream sources compile strictly.
  See [the tranche-C result](results/tapenade_set01_tranche_c_validation.txt).
- [x] Promote `lh068` through the focused tranche-D runner. Its
  statement-function `min` case exercises one active and one inactive branch
  away from zero, with forward mode plus independent reverse seeds for both
  scalar outputs. The runner checks strict upstream compilation, hand
  derivatives, finite differences, and both adjoint identities. See [the
  tranche-D result](results/tapenade_set01_tranche_d_validation.txt).
- [ ] Classify every status row: entry point, mode, options, dependencies,
  oracle, Tapenade result, and FortAD result. Replace placeholders only with
  reproducible evidence. There are 1,497 untriaged rows after the language
  boundary and nine set01 evidence rows.
- [ ] Convert every runnable Fortran candidate into a support case. Each valid
  differentiable path must pass a hand derivative, finite-difference sweep, or
  adjoint identity. Parser fixtures, invalid sources, and missing external
  dependencies need reproducible classifications.
- [ ] Record transformation time, compilation time, runtime, peak memory, and
  generated-source size for every runnable numerical case and applicable mode.
- [ ] Close every feature Tapenade supports on Fortran input, then cover the
  modern Fortran features outside Tapenade's corpus. C, C++, and Julia entries
  remain visible in the ledger and do not count as FortAD wins.
- [ ] Beat each applicable engine on feature coverage and on the measured
  runtime, build-time, and memory columns. Publish regressions and losses in the
  same result tables as wins.

### Build-time measurement

The 59-operator cross-engine table records runtime but lacks per-case AD
transformation and generated-object compilation time. The itpplasma cases
record both, plus complete case build time.

### itpplasma runtime polymorphism

Forward mode covers exact `TYPE IS` guards, an intermediate `CLASS IS` guard
matching a grandchild, and `CLASS DEFAULT`. Reverse mode covers the same two
exact runtime children in the first case. Its VJP is checked against a hand
adjoint, central differences, and the JVP/VJP adjoint identity. The dynamic
type remains a fixed, passive choice. The factory-created polymorphic
allocatable case has an independently checked primal and an explicit
allocation-lifetime derivative refusal. See the
[`manifest`](cases/itpplasma/manifest.toml), the first measured
[`record`](results/itpplasma_polymorphic_select_type_validation.txt), and the
advanced measured [`record`](results/itpplasma_polymorphism_advanced_validation.txt).

A procedure-pointer callback is now an explicit boundary case. Its primal runs
both targets, while the transform exits nonzero, names `selected_callback`, and
writes no derivative file. The equivalent explicit `SELECT TYPE` wrapper runs
and matches hand JVPs. See the paired
[`record`](results/itpplasma_callback_boundary_validation.txt).

This records a safe refusal, not procedure-pointer support. The first measured
case now closes two-child reverse `SELECT TYPE` dispatch. Broader n-way and
switch-boundary coverage remains open. Deferred type-bound calls, active
model components, arrays of polymorphic objects, procedure-pointer
differentiation, and alias-aware object lifetimes remain open.
The separate bounded concrete type-bound-call oracle is implemented in FortAD,
but it is not yet a timed case in this corpus.

The OO boundary matrix now has an executable refusal record at
`results/itpplasma_oo_boundaries_validation.txt`. Its three primals are valid
and independently checked before transformation: an abstract deferred binding
with a two-level override. It also has an allocatable polymorphic owner using
`move_alloc`, replacement, and finalization, plus procedure-pointer callbacks
carrying a `class(*)` context with reassignment and a null path. FortAD exits
nonzero and
writes no derivative for each. These records make P8.4-P8.6 boundaries
reproducible, but they do not close the positive derivative work: generated
bindings, active ownership, callback JVP/VJP rules, and switch-boundary
diagnostics remain open.

### Procedure interfaces and complex values

The manifest contains three independent slices for the next Phase 7/11
boundaries: optional/keyword calls, generic rank resolution, and the B10
intrinsic complex slice. Optional/keyword calls and the two `present` paths
have a generated JVP, a hand derivative, and a central finite-difference check.
Generic rank
resolution compiles and runs as valid Fortran, then records FortAD's named
refusal without producing a derivative file. The B10 intrinsic complex slice
is positive. Complex BLAS and a real-valued non-holomorphic output remain
separate work.

See [`cases/itpplasma/manifest.toml`](cases/itpplasma/manifest.toml), the
[`case pages`](README.md#itpplasma-language-cases), and
[`results/itpplasma_interfaces_validation.txt`](results/itpplasma_interfaces_validation.txt).

### itpplasma end-to-end closeout

“Supported” means that the same case passes every gate below. A refusal is a
result only when the primal is valid, the transform fails at the named
boundary, no derivative artifact is emitted, and the diagnostic is stable.

- [ ] **Interfaces (P7):** optional and keyword arguments, `present`, elemental
  calls, generic rank resolution, assumed-rank/`select rank`, fixed form,
  preprocessing, includes, and real-coordinate complex JVP/VJP.
- [ ] **Objects (P8):** concrete `pass`/`nopass`/named-pass calls, inherited
  bindings, abstract deferred bindings, runtime `TYPE IS`/`CLASS IS` dispatch,
  active components, arrays of polymorphic objects, and receiver cotangents.
- [ ] **Lifetimes (P8):** allocatable components, `allocate(source=...)`,
  assignment, `move_alloc`, replacement, finalization, and alias/section
  checks. Either differentiate the executed lifetime or record the exact
  refusal boundary.
- [ ] **Callbacks (P8):** active procedure pointers, `class(*)` context,
  reassignment, null paths, and callback JVP/VJP rules. A passive callback
  choice is a separate case from a differentiated callback body.
- [ ] **Boundaries and numerics (P8/P9):** branch, clamp, dispatch, I/O,
  external-library, solve, adaptive-step, and stochastic boundaries are
  either covered on a fixed smooth path or refused before code generation.

Each positive case needs a strict primal build, generated-code build and run,
hand or symbolic derivative, a central-difference sweep, and a JVP/VJP adjoint
identity where both modes exist. Each record also stores transform time,
generated-source size, compile time, runtime, and peak memory. The matrix is
closed only when every row is positive evidence or an independently checked,
reproducible refusal; “not tested” is not coverage.

## Harness notes for anyone extending this

- `scripts/build_fortnum_suite.sh` and `scripts/build_fortfem_suite.sh`
  compile and link each kernel's own primal (`${k}_primal.o`). Enzyme gets
  its own copy through the C-bound variant, which carries a different
  symbol, so there is no clash.
- Both engines are compiled by the same flang, deliberately: the comparison
  is of the derivative code, not of two compilers.
- fortsym kernels are wrapped with the same batch loop as the other engines
  so what is timed is the kernel rather than three different callers.
- `scripts/make_fortfem_cases.py` generates the fortfem cases from fortfem's
  extracted primals. Its `CHOSEN` list currently names all 44 catalogue
candidates. One has no generated source and one is excluded from the
  cross-engine harness as described above.
- A single evaluation of most of these kernels is far below timer
  resolution. Everything is batched, which is also how fortfem and fortnum
  actually call them: once per cell or per quadrature point.
