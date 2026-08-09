# fortad-bench roadmap

This repository is where fortad's performance claim is demonstrated or
refuted. It holds the workloads, the engine adapters, the harness, and the
committed results. `README.md` reports the current numbers. This file tracks
what is missing from them.

## Status, 2026-08-09

Coverage stands at 59 downstream operators: 17 in the fortnum suite and 42 in
the fortfem suite. A separate Enzyme-native suite contributes five additional
operators, reported outside that 59-operator cross-engine total.
Every operator that both Enzyme and fortad can differentiate has numbers
recorded. Two measurements exceed the 30% band agreed for the port. Both are
named below.

This is not yet a claim to beat every AD engine. The committed same-machine
timing table is FortAD versus Enzyme. The pinned Tapenade ledger now has 921
classified rows out of 2,014 (45.7% overall), including 413 of the 1,432
strict pure-Fortran rows (28.8%). The current queue contains 1,093 candidates:
1,019 pure Fortran and 74 mixed-language rows. A broader feature or performance
lead needs the remaining corpus classifications and the end-to-end itpplasma
matrix below.

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
makes it the comparison baseline for the `rk4` reverse result. Corpus support
is wired into the harness for the full pinned checkout. The current ledger
classifies 413 pure-Fortran rows and 508 non-Fortran or invalid-source rows;
1,019 pure-Fortran rows remain untriaged. The next8 compiler-clean cases
are recorded in `cases/tapenade-queue-shard-next8/`, and the next9 shard adds
four more exact-source closures in `cases/tapenade-queue-shard-next9/`; next10
adds four more rows in `cases/tapenade-queue-shard-next10/`; next11 adds four
more exact-source rows in `cases/tapenade-queue-shard-next11/`; next12 adds
four more exact-source rows in `cases/tapenade-queue-shard-next12/`; next13 adds
four more exact-source rows in `cases/tapenade-queue-shard-next13/`; next14 adds
four varied modern/pure-Fortran rows in `cases/tapenade-queue-shard-next14/`; next15
adds four modern-feature rows in `cases/tapenade-queue-shard-next15/`; next16
adds four queue-order modern rows in `cases/tapenade-queue-shard-next16/`; next17
adds the next four queue-order set01 rows in `cases/tapenade-queue-shard-next17/`; next18
adds the following four queue-order set01 rows in `cases/tapenade-queue-shard-next18/`; next19
adds the following four queue-order set01 rows in `cases/tapenade-queue-shard-next19/`; next20
adds `set01/lh114`, `lh115`, `lh117`, and `lh118` with dependent-inference,
mutating-call, COMMON-state, and active-I/O boundaries. Next42 closes
`set03/lh068`, `set04/v002`, `set04/v003`, and `set04/v012`; next43 closes
`set04/v018`, `set04/v043`, `set07/v496`, and `set10/lh238`, with fresh
Tapenade probes, exact hashes, FortAD boundaries, and independent
behavioral/refusal oracles.

The product target is the 1,432-row strict pure-Fortran population. Its current
status breakdown is 63 runnable cases, 134 measured expected refusals, 34
invalid-upstream closures, 177 additional FortAD feature boundaries, and five
other bounded evidence closures; 1,019 pure-Fortran rows remain untriaged. The 74 mixed
C/C++-Fortran rows stay in a separate dependency lane. “Expected refusal” means
a reproducible FortAD boundary with a valid upstream case; “invalid-upstream
closure” means the original case cannot be compiled or otherwise exercised
independently, so it is not evidence of a FortAD limitation.

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
  partition the 1,161 remaining candidates into 74 mixed-language-risk, 0
  historical-failure, 0 no-entry-point, 256 program, and 831 procedure
  candidates. An orthogonal missing-dependency-risk signal covers 112 rows
  with non-local include hints. Include targets are dependency-risk signals
  only. This queue does not claim that any source parses or builds.
- [x] Generate the pure-Fortran candidate handoff with
  `scripts/batch_tapenade_fortran.py`. It deterministically joins the queue,
  static entry-point hints, and compiler-backed file evidence for every pure
  Fortran row, while keeping mixed-language rows out and preserving the
  evidence-only boundary. Its `next_action` field schedules entry-point and
  dependency probes without changing the status ledger.
- [x] Make compiler-backed triage deterministic, shardable, and resumable.
  `scripts/triage_tapenade_fortran.py --resume` atomically checkpoints
  candidate rows and validates queue, shard, compiler, and source-set identity
  before reuse. Repeated `--merge-input` arguments require complete coverage,
  reject mixed compiler identities and non-compiler evidence, and write the
  canonical report without touching curated ledger statuses. The four-shard
  compiler totals are 2,024 accepted files, 1,422 syntax errors, and 147
  include fragments; they are evidence-only input. A canonical report
  replacement must go through this merge path.
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
- [x] Promote `lh001` through the focused tranche-E runner. Its fixed-form
  external `sub1` call and in-place state writes pass strict upstream
  compilation, FortAD forward/reverse generation, hand derivatives, a
  four-step finite-difference sweep, and the adjoint identity. See [the
  tranche-E result](results/tapenade_set01_tranche_e_validation.txt).
- [x] Promote `lh049` through the focused tranche-F runner. Its dependency-free
  fixed-form nonlinear result and in-place `y` update pass strict upstream
  compilation, FortAD forward/reverse generation, hand derivatives, a
  four-step finite-difference sweep, and the adjoint identity. See the
  [tranche-F result](results/tapenade_set01_tranche_f_validation.txt).
- [x] Promote the dependency-free `todoF90/REFERENCES/v420` historical case.
  The runner compiles its unmodified upstream source, invokes Tapenade for
  parser/tangent/adjoint output, generates FortAD JVP/VJP code, and checks hand
  derivatives, four-step finite differences, and the adjoint identity. See the
  [v420 case](cases/tapenade-known-failures/v420/README.md) and its
  [measurement record](results/tapenade_known_failure_v420_validation.txt).
- [x] Promote `lh002` through the focused tranche-G runner. Its dependency-free
  fixed-form branch and nested-call regression pass strict upstream compilation,
  FortAD forward/reverse generation, hand derivatives on both branch sides, a
  four-step finite-difference sweep, and the adjoint identity. See the
  [tranche-G result](results/tapenade_set01_tranche_g_validation.txt).
- [x] Record the `lh004` bounded branch-in-loop refusal through the focused
  tranche-H runner. Its fixed-trace primal and forward transform pass an
  independent hand/finite-difference oracle, while reverse mode returns the
  exact control-flow reversal diagnostic. See the
  [tranche-H result](results/tapenade_set01_tranche_h_refusal_validation.txt).
- [x] Record the exact `lh012`-`lh014` generated-compile boundaries through
  the focused `lh007`-`lh015` runner. Fresh Tapenade parser, tangent, and
  reverse files compile strictly. FortAD's forward/reverse generated-code
  statuses and exact compiler diagnostics are retained, with independent
  hand, central-difference, and adjoint checks on safe observations. See the
  [tranche result](results/tapenade_set01_lh007_015_refusal_validation.txt).
- [x] Record the `f03typf01` abstract OO boundary. Tapenade emits malformed
  deferred-binding output. FortAD refuses the mapped direct deferred call.
  The independent child-value/finite-difference oracle keeps this a
  reproducible expected refusal, not a support claim. See the
  [case](cases/tapenade-set12/f03typf01.md) and
  [validation record](results/tapenade_f03typf01_oo_validation.txt).
- [x] Close tranche AH: `set01/lh136`, `set01/lh144`, `set02/lh192`,
  `set12/cmplxstep01`, and `set12/f03fptr01`. Fresh pinned Tapenade runs,
  exact FortAD outcomes, source hashes, and independent arithmetic or
  finite-difference oracles record the fixed-form declaration, reverse
  signature, checkpoint storage, mutable-global, and procedure-pointer
  boundaries. The modern cases are summarized in
  [`modern-tranche-a`](cases/tapenade-set12/modern-tranche-a.md).
- [x] Promote the set12 profile tranche: `jlb012` is an exact free-form
  expected refusal after fresh Tapenade and FortAD products fail strict
  generated-source compilation; `profile01` is a fixed-form runnable case
  whose FortAD forward/reverse products pass strict compilation and runtime.
  Both rows pass the independent hand, central-difference, and adjoint
  oracle. See the profile-tranche manifest, case notes, and validation record.
- [x] Record `ADFirstAidKit/testMemSizef.f` as a runnable ABI probe with no
  derivative contract. The unmodified program and Tapenade parser round-trip
  match an independent `storage_size` oracle for all 15 reported types.
  Tapenade emits `AD06`. FortAD rejects the program as a non-procedure, and both
  modes emit no derivative source. See the
  [case](cases/tapenade-first-aid-kit/testMemSizef/README.md) and
  [validation record](results/tapenade_firstaid_memsize_refusal_validation.txt).
- [x] Record `ADFirstAidKit/validityTest.f`. The exact legacy source and fresh
  Tapenade tangent/adjoint outputs compile, and an independent executable
  checks its interval-state transitions. FortAD refuses the exact `COMMON`
  statement before differentiation. See the [case](cases/tapenade-first-aid/README.md).
- [x] Promote set01 `bd01`, `bd02`, and `bd03` with fresh Tapenade parser,
  tangent, and adjoint generation, strict generated-source compilation, and an
  independent hand/finite-difference/adjoint oracle. See the
  [tranche-L manifest](cases/tapenade-set01/tranche-l-bd-ht-manifest.toml),
  [case notes](cases/tapenade-set01/tranche-l-bd-ht.md), and
  [measurement record](results/tapenade_set01_tranche_l_bd_ht_validation.txt).
- [x] Promote set01 `lh085` and `lh092` with fresh Tapenade parser, tangent,
  and adjoint generation, strict generated-source compilation, and independent
  hand/finite-difference/adjoint oracles. See the
  [tranche-N manifest](cases/tapenade-set01/tranche-n-lh083-096-manifest.toml),
  [case notes](cases/tapenade-set01/tranche-n-lh083-096.md), and
  [measurement record](results/tapenade_set01_lh083_096_validation.txt).
- [x] Promote set01 `lh086` with fresh Tapenade parser, tangent, and adjoint
  generation, strict generated-source compilation, and an independent Newton-map
  JVP/VJP, central-difference, and adjoint oracle. The exact upstream routine is
  in-place, so the runnable FortAD case uses a bounded port with its final iterate
  exposed as an output. See the [tranche-O manifest](cases/tapenade-set01/tranche-o-lh086-manifest.toml),
  [case notes](cases/tapenade-set01/tranche-o-lh086.md), and
  [measurement record](results/tapenade_set01_lh086_validation.txt).
- [x] Promote the parallel cross-set tranche: `set01/bd05`, `set02/lh150`,
  `set03/ht09`, `set04/lh110`, `set05/v052`, and `set06/v234`. Every case has
  an exact pinned upstream compile, fresh Tapenade parser/tangent/reverse
  generated-source compile, FortAD forward/reverse evidence, and an
  independent hand/finite-difference/adjoint oracle. The `bd05` case also
  closes the legacy implicit loop-index declaration gap in generated FortAD
  sources. See the [case manifests](cases/tapenade-set01/tranche-p-bd05-manifest.toml),
  [set02 record](cases/tapenade-set02/tranche-a-lh150.md),
  [set03 record](cases/tapenade-set03/tranche-p-ht09.md),
  [set04 record](cases/tapenade-set04/tranche-a-lh110.md),
  [set05 record](cases/tapenade-set05/tranche-v052.md), and
  [set06 record](cases/tapenade-set06/tranche-a-v234.md).
- [x] Promote shard-0 `set04/lh148` entry `module1::toto` with exact pinned
  source hashes, fresh Tapenade parser/tangent/reverse generation and strict
  compilation, FortAD forward/reverse strict compilation, and an independent
  product JVP/VJP finite-difference/adjoint oracle. See the
  [manifest, runner, and evidence](cases/tapenade-set04/lh148/notes.md).
- [x] Promote set01 `lh018` with fresh Tapenade parser, tangent, and reverse
  generation, strict generated-source compilation, and an independent
  closed-form array/scalar JVP/VJP oracle with central differences and the
  adjoint identity. See [tranche-Q notes](cases/tapenade-set01/tranche-q-lh018.md),
  [manifest](cases/tapenade-set01/tranche-q-lh018-manifest.toml), and
  [measurement record](results/tapenade_set01_lh018_validation.txt).
- [x] Record set01 `lh007`, `lh009`, `lh011`, and `lh015` as independently
  checked exact-source boundaries: one `COMMON` refusal, one computed-GOTO
  refusal, and two invalid-upstream closures. Their bounded oracles do not
  turn repaired sources into FortAD support claims. See the [tranche-R notes](cases/tapenade-set01/README.md#tranche-r-lh007-lh009-lh011-and-lh015)
  and the linked manifests and measurement records.
- [x] Close set01 `lh020`, `lh021`, `lh024`, `lh025`, `lh026`, and `lh027` with
  pinned exact-source compilation, fresh Tapenade generation, FortAD evidence,
  and independent contract/oracle checks. `lh020`, `lh025`, and `lh027` are
  bounded runnable ports; `lh021`, `lh024`, and `lh026` are reproducible exact
  source refusals with passing bounded oracles. See the [tranche-S notes](cases/tapenade-set01/README.md#tranche-s-lh020-lh021-lh024-lh025-lh026-and-lh027).
- [x] Close set01 `lh029`, `lh030`, `lh031`, `lh034`, `lh035`, and `lh036` with
  strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local evidence. `lh029`, `lh030`, and `lh031` are bounded
  runnable ports; `lh034` is an expected refusal with a passing forward oracle;
  `lh035` and `lh036` are invalid-upstream closures. See the [tranche-T notes](cases/tapenade-set01/README.md#tranche-t-lh029-lh030-lh031-lh034-lh035-and-lh036).
- [x] Close set01 `lh037`, `lh038`, `lh041`, `lh042`, `lh044`, and `lh045` with
  strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local evidence. `lh038`, `lh041`, and `lh045` retain exact
  FortAD refusal boundaries with bounded forward checks; `lh037`, `lh042`, and
  `lh044` are invalid-upstream closures. See the [tranche-U notes](cases/tapenade-set01/README.md#tranche-u-lh037-lh038-lh041-lh042-lh044-and-lh045).
- [x] Close set01 `lh046`, `lh047`, `lh048`, `lh050`, `lh051`, and `lh053` with
  strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local evidence. `lh047`, `lh048`, `lh051`, and `lh053` are
  bounded forward refusals; `lh046` is invalid upstream; `lh050` exposes an
    exact FortAD semantic mismatch and is not promoted as support. See the
    [tranche-V notes](cases/tapenade-set01/README.md#tranche-v-lh046-lh047-lh048-lh050-lh051-and-lh053).
- [x] Close set01 `lh054`, `lh055`, `lh056`, `lh059`, `lh060`, and `lh061` with
  strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local contracts. `lh054` records an exact FortAD semantic
  mismatch, `lh055`, `lh059`, and `lh060` retain bounded forward/refusal
  evidence, `lh056` is invalid upstream, and `lh061` is an unresolved callback
  boundary. See the [tranche-W notes](cases/tapenade-set01/README.md#tranche-w-lh054-lh055-lh056-lh059-lh060-and-lh061).
- [x] Close set01 `lh063`, `lh064`, `lh065`, `lh067`, `lh069`, and `lh070` with
  strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local contracts. `lh063` and `lh065` are invalid-upstream
  closures; the other four retain exact FortAD refusals with bounded numerical
  witnesses. See the [tranche-X notes](cases/tapenade-set01/README.md#tranche-x-lh063-lh064-lh065-lh067-lh069-and-lh070).
- [x] Close set01 `lh071`, `lh072`, `lh073`, `lh075`, `lh076`, and `lh077` with
  strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local contracts. `lh071` and `lh075` are invalid-upstream
  closures; `lh072`, `lh073`, `lh076`, and `lh077` retain exact FortAD refusals
  with bounded, explicitly scoped witnesses. See the [tranche-Y notes](cases/tapenade-set01/README.md#tranche-y-lh071-lh072-lh073-lh075-lh076-and-lh077).
- [x] Close `todoF90/REFERENCES/bd01`, `bd11`, `v01`, `v02`, `v05`, and `v07`
  with strict exact-source/reference checks, fresh Tapenade generation, and
  independent case-local contracts. `v05` and `v07` are invalid-upstream
  closures; the other four retain exact FortAD refusals with bounded, explicitly
  scoped witnesses where semantics can be checked. See the [tranche-Z notes](cases/tapenade-set01/README.md#tranche-z-todof90-references-bd01-bd11-v01-v02-v05-and-v07).
- [x] Close `todoF90/REFERENCES/v100`, `v101`, `v144`, `v270`, `v322`, and
  `v377` with strict exact-source/reference checks, fresh Tapenade generation,
  and independent case-local contracts. `v144`, `v270`, `v322`, and `v377` are
  invalid-upstream closures; `v100` and `v101` retain exact FortAD refusals with
  bounded witnesses. See the [tranche-AA notes](cases/tapenade-set01/README.md#tranche-aa-todof90-references-v100-v101-v144-v270-v322-and-v377).
- [x] Close `todoF90/REFERENCES/v385`, `v402`, `v412`, `v413`, `v414`, and
  `v415` with strict exact-source/reference checks, fresh Tapenade generation,
  and independent case-local contracts. `v385`, `v402`, and `v412` are
  invalid-upstream closures; `v413`, `v414`, and `v415` retain expected FortAD
  refusal boundaries without bounded ports. See the [tranche-AB notes](cases/tapenade-set01/README.md#tranche-ab-todof90-references-v385-v402-v412-v413-v414-and-v415).
- [x] Close `todoF90/REFERENCES/v416`, `v417`, `v418`, `v419`, `v421`, and
  `v422` with strict exact-source/reference checks, fresh Tapenade generation,
  and independent case-local contracts. `v416` adds a bounded declaration-order
  witness; `v418` and `v421` are invalid-upstream closures; the other three
  retain expected FortAD refusal boundaries. See the [tranche-AC notes](cases/tapenade-set01/README.md#tranche-ac-todof90-references-v416-v417-v418-v419-v421-and-v422).
- [x] Close `todoF90/REFERENCES/v425`, `v426`, `v427`, `v469`, `v500`, and
  `v503` with strict exact-source/reference checks, fresh Tapenade generation,
  and independent case-local contracts. `v469` adds a bounded strict-tab
  witness; `v503` is an incomplete invalid-upstream closure; the other four
  retain expected FortAD refusal boundaries. See the [tranche-AD notes](cases/tapenade-set01/README.md#tranche-ad-todof90-references-v425-v426-v427-v469-v500-and-v503).
- [x] Close `todoF90/REFERENCES/v504`, `v505`, `v508`, `v519`, `v526`, and
  `v547` with strict exact-source/reference checks, fresh Tapenade generation,
  exact FortAD parser/forward/reverse probes, and independent case-local
  contracts. `v504` and `v526` add bounded ports; `v505`, `v508`, `v519`, and
  `v547` preserve callback, global-state, standalone-program, and legacy
  declaration refusal boundaries. See the [tranche-AE notes](cases/tapenade-set01/README.md#tranche-ae-todof90-references-v504-v505-v508-v519-v526-and-v547).
- [x] Close `nonRegressions/set01/lh000`, `set02/v065`, `set04/v017`,
  `set04/v025`, `set05/v075`, and `set05/v146` with strict source/reference
  checks, fresh Tapenade no-root probes, and independent no-entry semantic
  contracts. These are empty, `BLOCKDATA`, or module-only cases; no synthetic
  procedure or bounded derivative port is claimed. See the [tranche-AF notes](cases/tapenade-set01/README.md#tranche-af-nonregressionsset01lh000-set02v065-set04v017-set04v025-set05v075-and-set05v146).
- [x] Close the remaining no-entry queue: `set05/v147`, `v171`, `v177`,
  `v201`, `v216`, `set06/v316`, `v317`, `v320`, `v360`, `v362`,
  `set07/v485`, `v523`, `v544`, and `set11/vpf16`. Fresh pinned Tapenade
  parser/no-root probes, strict source/reference checks, repaired quiet FortAD
  refusals, and independent three-test contracts cover all fourteen; no
  synthetic root or derivative port is claimed. See the [tranche-AG notes](cases/tapenade-set01/README.md#tranche-ag-the-remaining-no-entry-point-queue).
- [x] Close set01 `lh093`, `lh094`, `lh097`, `lh098`, `lh102`, and `lh103` with
  fresh pinned Tapenade parser/forward/reverse generation, strict/legacy gates,
  exact FortAD probes, and independent three-test contracts. These six remain
  explicit refusal boundaries: I/O, external derivative summaries, external
  CNKLOG support, incomplete protected-expression output, and reverse
  per-iteration storage. See the six case directories under
  `cases/tapenade-set01/`.
- [x] Close set01 `ht02`, `ht03`, `lh104`, `lh105`, `lh107`, and `lh109` with
  fresh pinned Tapenade parser/forward/reverse generation, strict/legacy gates,
  exact FortAD probes, and independent three-test contracts. Five remain exact
  refusal boundaries for unsupported I/O, call boundaries, or reverse adjoint
  output; `lh107` is a runnable `MAX` sequence. See the six case directories
  under `cases/tapenade-set01/`.
- [x] Close set01 `B03`, `ala00`, `ala01`, and `ala02` with fresh pinned
  Tapenade parser/forward/reverse generation, strict/legacy gates, exact
  FortAD probes, and independent three-test contracts. All four remain exact
  refusal boundaries: `COMMON` at `B03`, and unsupported `PRINT`/legacy reverse
  boundaries in the fixed-point cases. See the four case directories under
  `cases/tapenade-set01/`.
- [x] Close set01 `B01` with fresh pinned Tapenade parser/forward/reverse
  generation, strict/legacy gates, exact FortAD probes, and an independent
  determinant-volume JVP/VJP contract. The exact source remains an explicit
  refusal at its legacy labeled-DO boundary; no repaired source is counted.
- [x] Close set01 `ala03`, `ala04`, `ala05`, and `bd04` with fresh pinned
  Tapenade generation, strict/legacy gates, exact FortAD probes, and
  independent JVP/VJP contracts. These remain explicit boundaries for MPI
  update rules, nested fixed-point names/legacy declarations, DO WHILE, and
  exact-source PRINT, respectively.
- [x] Promote shard-3 `set05/v125` and `set05/v137` with fresh exact-source
  Tapenade parser/forward/reverse generation, strict generated compilation,
  FortAD JVP/VJP transforms from checked ports, and independent hand,
  finite-difference, and adjoint-identity checks. See the [case record](cases/tapenade-set05-shard3-v125-v137/README.md)
  and [validation result](results/tapenade_set05_shard3_v125_v137_validation.txt).
- [x] Promote `set05/v054` `f_vector` with fresh pinned Tapenade
  parser/tangent/reverse generation, strict compilation, a FortAD JVP/VJP
  module-extraction port, and independent hand, finite-difference, and
  adjoint-identity checks. The elemental companion's strict Tapenade purity
  failure remains recorded as a boundary. See the [case record](cases/tapenade-set05/tranche-v054.md)
  and [validation result](results/tapenade_set05_v054_validation.txt).
- [ ] Classify every status row: entry point, mode, options, dependencies,
  oracle, Tapenade result, and FortAD result. Replace placeholders only with
  reproducible evidence. There are 1,087 untriaged pure-Fortran rows and 74
  mixed-language rows. The next8 through next16 shards closed thirty-six
  compiler-clean pure-Fortran rows with fresh Tapenade probes and independent
  Python oracles; next15 adds overloaded operators, nested derived-type
  arithmetic, and explicit COMMON/SAVE pointer-storage refusals; next16 adds
  pointer-result aliasing, allocation lifetime, module-state refusal, and one
  runnable derived-type affine procedure; next17 adds active-I/O,
  character-substring, legacy-labeled-DO, and invalid-generated-interface
  boundaries; next18 adds DO WHILE, COMMON/derived-storage, dependent-selection,
  and undefined-storage refusals; next19 adds legacy inference, array liveness,
  missing-reference/generated-interface, and invalid DO-variable boundaries;
  next20 adds dependent inference, mutating call actuals, COMMON state, and
  active-I/O boundaries.
  next21 adds active-I/O, legacy-GOTO, nested-DO-WHILE, and legacy-labeled-DO
  boundaries; next23 adds four modern-feature rows with module-state,
  pointer-alias, generated-interface, and reverse-dependent boundaries; next24
  adds four score-selected rows with nested pointer-derived context,
  module-state, and overloaded derived-type context boundaries; next25 adds
  four score-selected rows with pointer-alias, generic-call, allocatable-call,
  and generated derived-type-context boundaries; next26 wave6 adds
  `set04/lh113`, `set11/ompl07`, `set05/v179`, and `set06/v341` with
  module-state, OpenMP, active-I/O, and allocatable-derived-component
  boundaries. See the [next26 wave6 shard](cases/tapenade-queue-shard-next26-wave6/README.md).
  Continue in
  similarly bounded shards.
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

The positive runtime `SELECT TYPE` case also dispatches an abstract deferred
`response` binding to linear and quadratic children. Its generated JVP and VJP
pass hand, finite-difference, and adjoint oracles, and its measurement records
the cost of ten million dispatches. This is bounded fixed-trace support: the
selector is passive, the child implementations are in the same source, and
the dynamic type cannot change during a call.

A procedure-pointer callback is now an explicit boundary case. Its primal runs
both targets, while the transform exits nonzero, names `selected_callback`, and
writes no derivative file. The equivalent explicit `SELECT TYPE` wrapper runs
and matches hand JVPs. See the paired
[`record`](results/itpplasma_callback_boundary_validation.txt).

This records a safe refusal, not procedure-pointer support. The measured cases
now close bounded two-child reverse `SELECT TYPE` dispatch and bounded deferred
child bindings. Broader n-way and switch-boundary coverage remains open.
Direct class dispatch, active model components, arrays of polymorphic objects,
procedure-pointer differentiation, and alias-aware object lifetimes remain
open.
The separate bounded concrete type-bound-call oracle is implemented in FortAD,
but it is not yet a timed case in this corpus.

The OO boundary matrix now has an executable refusal record at
`results/itpplasma_oo_boundaries_validation.txt`. Its three primals are valid
and independently checked before transformation: an abstract deferred binding
with a two-level override. It also has an allocatable polymorphic owner using
`move_alloc`, replacement, and finalization, plus procedure-pointer callbacks
carrying a `class(*)` context with reassignment and a null path. FortAD exits
nonzero and
writes no derivative for each. These records make the remaining P8.5-P8.6
boundaries reproducible, but active ownership, callback JVP/VJP rules, and
switch-boundary diagnostics remain open.

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
  call them: once per cell or per quadrature point.
