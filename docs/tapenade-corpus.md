# Tapenade corpus

Fetch and verify the pinned checkout:

```bash
scripts/fetch_upstreams.py --corpus tapenade
```

The command checks out Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9`, verifies its Git tree and all
10,977 tracked paths, and verifies the committed static triage and status
ledger against that checkout before writing `docs/generated/tapenade-corpus.md`.
Both the checkout and generated inventory are gitignored. If a previous
gitignored checkout is incomplete or malformed, the pinned fetch rebuilds it
from a temporary checkout; a locally modified checkout is preserved and fails
the audit. A fresh clone therefore needs no separate seed or triage step.
Repeat the audit without a network request with:

```bash
scripts/fetch_upstreams.py --audit-corpora
```

The offline audit also checks
[`corpora/tapenade-status.csv`](corpora/tapenade-status.csv). The CSV has one
row for each candidate in the pinned Git tree. Recreate the initial scaffold
from an audited checkout with:

```bash
scripts/fetch_upstreams.py --seed-corpus-ledger tapenade
```

The seed command writes `untriaged` and `not-run` in every workflow field. It
refuses to overwrite a ledger after any row has been curated.
The audit rejects result changes on an `untriaged` row. A classified row must
replace every `untriaged` workflow placeholder before it passes.

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
The manifest enumerates 10,513 candidate-relevant paths. The full pinned
checkout contains 10,977 tracked files and 2,014 candidates. See
[`corpora/tapenade.toml`](corpora/tapenade.toml) for the exact paths and counts.

A candidate is a unit to classify. Some entries are runnable programs. Others
are expected output, parser fixtures, support files, or historical failures.
The inventory does not claim that FortAD currently differentiates any new
case.

## Static triage

[`corpora/tapenade-static.jsonl`](corpora/tapenade-static.jsonl) records source
metadata for every candidate. Regenerate it from the audited checkout with:

```bash
scripts/fetch_upstreams.py --write-corpus-triage tapenade
```

The report contains 6,078 tracked source and include files, 12,960 syntactic
entry-point hints, 2,488 include hints, and 2,348 Fortran `use` or Julia import
hints. The offline corpus audit reproduces the JSONL byte for byte.

| static classification | candidates | rule |
|---|---:|---|
| `fortran-runnable-candidate` | 330 | a tracked Fortran source contains a `program` declaration |
| `fortran-procedure-candidate` | 1,081 | a tracked Fortran source contains a subroutine or function declaration |
| `fortran-source-candidate` | 21 | tracked Fortran source exists without a detected entry point |
| `mixed-language-source` | 74 | tracked source uses Fortran and another language |
| `non-fortran-source` | 506 | tracked source contains no Fortran compilation unit |
| `harness-reference-data` | 2 | the candidate has no recognized source or include file |

These are filename and declaration hints. Reference derivatives checked into
Tapenade appear in `source_files` and may contribute entry-point hints. A
`fortran-runnable-candidate` has not passed a compiler, Tapenade, FortAD, or a
numerical oracle. Symlink paths stay in `source_files`, but their targets are
not read when generating hints. The line-based extractor can miss multiline
declarations and does not resolve include or module targets.

Materialize the FortAD language boundary from that report with:

```bash
scripts/classify_tapenade_nonfortran.py
scripts/classify_tapenade_nonfortran.py --check
```

The command classifies 506 candidates containing only C, C++, CUDA, or Julia
source as unsupported FortAD input. It separately marks two candidates with no
recognized source. Entry points, options, modes, and dependencies remain
`not-inspected`. Tapenade stays `not-run`. The FortAD result records either an
unsupported source language or no recognized source. The command does not run
  either engine. It leaves 1,099 pure-Fortran and 74 mixed-language rows
  untriaged. The ledger currently has 63 executable evidence rows, 236 bounded
  pure-Fortran refusal or feature/dependency classifications, and 34
  invalid-upstream closures. The profile, shard-3, and shard-0
  tranches add exact-source
  Tapenade generation, strict generated compilation, FortAD transforms, and
  independent derivative checks; the shard-0 case is `set04/lh148`.

Build the next-tranche queue without changing those ledger statuses:

```bash
scripts/queue_tapenade_fortran.py
scripts/queue_tapenade_fortran.py --check
```

[`corpora/tapenade-fortran-queue.jsonl`](corpora/tapenade-fortran-queue.jsonl)
and its [summary](corpora/tapenade-fortran-queue.md) partition the 1,173 rows
into 74 mixed-language-risk candidates, 0 historical-failure candidates, 0
 rows with no entry-point hint, 263 program candidates, and 836 procedure
candidates. An orthogonal `missing-dependency-risk` category covers 112 rows
with non-local include hints. The queue uses only static filename and line-based
declaration/include/use hints. An unresolved include is reported as a
dependency risk signal, not as proof that a dependency is missing. No queue
label claims parsing, compilation, transformation, runtime, or correctness.

The exact fixed-form `set02/lh193` and `set02/lh194` AMPI candidates are
recorded separately as `blocked-missing-dependency`: strict and legacy
compilation reach the missing `ampi/ampif.h`/`mpif.h` chain in the pinned
checkout. They are not classified as invalid upstream, and neither Tapenade
nor FortAD is invoked. See the [`lh193 case notes`](../cases/tapenade-set02/lh193/notes.md),
[`lh193 manifest`](../cases/tapenade-set02/lh193/manifest.toml),
[`lh193 result`](../cases/tapenade-set02/lh193/result.txt), and the
corresponding [`lh194 case notes`](../cases/tapenade-set02/lh194/notes.md),
[`manifest`](../cases/tapenade-set02/lh194/manifest.toml), and
[`result`](../cases/tapenade-set02/lh194/result.txt).

Run the compiler-backed evidence pass after fetching the pinned checkout:

```bash
scripts/triage_tapenade_fortran.py --jobs 4
scripts/triage_tapenade_fortran.py --check
```

The run is resumable and shard-safe. Give each worker a distinct output file;
`--resume` atomically checkpoints completed candidate rows and validates that a
checkpoint belongs to the selected shard, compiler, and queue source set:

```bash
scripts/triage_tapenade_fortran.py --shard-count 4 --shard-index 0 \
  --jobs 4 --resume --output results/triage/shard-0.jsonl \
  --summary results/triage/shard-0.md
```

After all shards finish, promote only the complete compiler-only handoff to
the canonical report with repeated `--merge-input` arguments:

```bash
scripts/triage_tapenade_fortran.py \
  --merge-input results/triage/shard-0.jsonl \
  --merge-input results/triage/shard-1.jsonl \
  --merge-input results/triage/shard-2.jsonl \
  --merge-input results/triage/shard-3.jsonl \
  --output docs/corpora/tapenade-fortran-compiler.jsonl \
  --summary docs/corpora/tapenade-fortran-compiler.md
```

Merge refuses partial or duplicate coverage, queue/source-set drift, mixed
compiler identities, and rows whose evidence scope is not compiler-only. The
result remains evidence-neutral input for the batch handoff; it never changes
the curated status ledger or adds a derivative claim. A merge is the only
supported way to replace the canonical report after sharded triage.

[`corpora/tapenade-fortran-compiler.jsonl`](corpora/tapenade-fortran-compiler.jsonl)
and its [summary](corpora/tapenade-fortran-compiler.md) contain one stable row
per queued candidate and one status/hash record per tracked Fortran source.
The latest complete full-queue run accepted 1,874 files, rejected 1,399 with
syntax or dependency diagnostics, and listed 74 include fragments without
compiling them as standalone units.
Fixed/free source forms get strict syntax-only flags and local include roots;
`.inc`/`.fh` fragments are listed as evidence but not compiled alone. A
`compiled` status is only compiler acceptance, never a transformation or
derivative-support claim. Use `--shard-index`/`--shard-count` for independent
workers and the documented `--merge-input` command to produce the same sorted
report from shards. The generated report is intentionally separate from the
ledger, so compiler-only coverage can be refreshed without reclassifying any
candidate.

The [bounded known-failure and large-example report](corpora/tapenade-known-failures.md)
adds compiler and Tapenade parser evidence for 59 additional rows. It is still
source-viability evidence. Every row remains `untriaged` until generated-code
and independent numerical-oracle gates exist.

The first curated rows are the set01 checks in
[`cases/tapenade-set01/README.md`](../cases/tapenade-set01/README.md): `lh001`, `lh002`,
`lh004`, `lh012`, `lh013`, `lh014`, `lh023`, `lh032`, `lh049`, `lh057`, `lh058`, `lh068`, `lh088`, and `lh134`. The exact in-place
`lh066` reverse shape and the one-trip-loop `bd06` reverse shape are
independently compiler-checked expected refusals. Both are recorded in the
tranche results:
[`lh066`](../results/tapenade_set01_refusals.txt) and
[`bd06`](../results/tapenade_set01_tranche_b_validation.txt).
The `lh058` support result is in
[`tranche-c`](../results/tapenade_set01_tranche_c_validation.txt).
The `lh068` statement-function result is in
[`tranche-d`](../results/tapenade_set01_tranche_d_validation.txt).
The `lh049` in-place polynomial result is in
[`tranche-f`](../results/tapenade_set01_tranche_f_validation.txt).
The `lh002` branch and nested-call result is in
[`tranche-g`](../results/tapenade_set01_tranche_g_validation.txt).
The `lh004` branch-in-loop refusal result is in
[`tranche-h`](../results/tapenade_set01_tranche_h_refusal_validation.txt).
The `lh012`-`lh014` generated-compile refusal result is in
[`lh007-015`](../results/tapenade_set01_lh007_015_refusal_validation.txt).
The adjacent `lh017` support and `lh022`/`lh028` reverse-boundary results are
in [`tranche-l`](../results/tapenade_set01_lh017_032_validation.txt).
The adjacent `lh039` support and exact `lh033`/`lh040` fixed-form boundaries
are in [`tranche-m`](../results/tapenade_set01_lh033_047_validation.txt).
The adjacent `lh085` and `lh092` large-expression and nested-call support
results are in [`tranche-n`](../results/tapenade_set01_lh083_096_validation.txt).
The bounded Newton-map port for `lh086`, with hand JVP/VJP, central-difference,
and adjoint checks, is in [`tranche-o`](../results/tapenade_set01_lh086_validation.txt).
The same-file function-composition port for `lh018`, with a closed-form
array/scalar JVP/VJP, is in [`tranche-q`](../results/tapenade_set01_lh018_validation.txt).
The `lh007` exact `COMMON` boundary and bounded oracle are in
[`lh007`](../results/tapenade_set01_lh007_refusal_validation.txt); invalid-source
closures for `lh009` and `lh015`, and the computed-GOTO boundary for `lh011`, are
linked from the set01 case notes.
The parallel cross-set tranche adds six positive rows: `set01/bd05`,
`set02/lh150`, `set03/ht09`, `set04/lh110`, `set05/v052`, and `set06/v234`.
Their manifests, runners, and measurement records are linked from the
corresponding case directories. The shard-0 `set04/lh148` `module1::toto`
entry is independently promoted in
[`cases/tapenade-set04/lh148`](../cases/tapenade-set04/lh148/notes.md).
The next pure-Fortran queue candidate, `set02/lh198` `top(x,y)`, is recorded
as an expected FortAD refusal. The unchanged fixed-form primal and stored
references pass strict F2018 and legacy compiler gates, fresh pinned
Tapenade parser/tangent/reverse products pass both gates, and the exact
primal runs with `y=15`. FortAD check/re-emission passes, while exact forward
and reverse deliberately stop at the active `AAA` call because no derivative
rule is registered and emit no non-empty derivative source. An independent
COMMON-block dataflow oracle checks the primal, JVP, central differences, and
adjoint identity; this is not an invalid-upstream closure or a repaired-port
claim. See the [`case notes`](../cases/tapenade-set02/lh198/notes.md),
[`manifest`](../cases/tapenade-set02/lh198/manifest.toml), and
[`result`](../cases/tapenade-set02/lh198/result.txt).
The next fixed-form candidate, `set02/v067` `ADJ_FCN(T,Y,YP,RESULT,RP)`, is
closed as a valid-source expected refusal. The exact `program.f` and stored
`program_p.f` pass strict F2018 and legacy compilation. Fresh exact-source
Tapenade probes report `unit ADJ_FCN: not found` on the CR-only source and emit
no derivative products; FortAD's exact parser passes, its forward product is
only an empty stub, and its reverse probe stops at the case-insensitive
assignment boundary. The independent source oracle checks `T=Y+pi`, central
differences, and the adjoint identity. No line-ending rewrite, repaired port,
or exact derivative support claim is made. See the
[`case notes`](../cases/tapenade-set02/v067/notes.md),
[`manifest`](../cases/tapenade-set02/v067/manifest.toml), and
[`result`](../cases/tapenade-set02/v067/result.txt).
The next large-example candidate, `examples/big01/B04`, is an
`unsupported-invalid-upstream-fortran` closure. The exact and stored fixed-form
sources fail strict and legacy compiler gates because of duplicate main
programs, malformed legacy syntax, and a missing `DIFFSIZES.inc` in the stored
derivative references. Fresh pinned Tapenade generates parser, tangent, and
reverse products, but the parser product fails the same source gate and reverse
is blocked by that missing include. FortAD refuses all exact requests at the
malformed token on line 20599. No source repair or derivative oracle claim is
made. See the [`case notes`](../cases/tapenade-big01-B04/notes.md),
[`manifest`](../cases/tapenade-big01-B04/manifest.toml), and
[`result`](../cases/tapenade-big01-B04/result.txt).
The recent small pure-Fortran promotions are `set05/v060` and `set05/v061`,
both selecting `M::func(t,u)`. The next queue-priority row is now promoted as
`set05/v062` `M::func(t,u)`, with the unchanged upstream source compiled and
hashed, fresh pinned parser/tangent/reverse generation, strict FortAD
forward/reverse compilation, and an independent average-function
hand/finite-difference/adjoint oracle. Its standards-clean selected closure is
an explicit-result extraction; it is not a repaired upstream source. See the
[`case manifest`](../cases/tapenade-set05/v062_manifest.toml) and
[`validation result`](../cases/tapenade-set05/v062_result.txt).

The immediately following compiler-clean row, `set05/v063`, was probed at all
three source procedures and is not promoted: FortAD refuses its overlapping
whole-array sections. The next small numeric closure, `set05/v064`
`LIB::mppsum_real(ptab)`, is promoted with the unchanged exact source and all
stored Tapenade references compiled and hashed, fresh pinned parser/tangent/
reverse generation, strict FortAD forward/reverse compilation, and an
independent hand/finite-difference/adjoint oracle. Its standards-clean
value-map extraction is explicitly not a repaired upstream source. See the
[`case manifest`](../cases/tapenade-set05/v064_manifest.toml) and
[`validation result`](../cases/tapenade-set05/v064_result.txt).

The next queue-selected pure-Fortran row, `set05/v065`, selects
`LIB::mppsum_real2(ptab,cst,str)`. Its exact source and stored tangent/adjoint
references compile strictly, fresh pinned Tapenade parser/tangent/reverse
generation compiles strictly, and the selected ten loop assignments pass a
FortAD vector value-map forward/reverse harness plus independent hand,
central-difference, and adjoint checks with `ptab` active and `cst` passive.
The vector map is not a repaired upstream source. See the
[`case manifest`](../cases/tapenade-set05/v065_manifest.toml) and
[`validation result`](../cases/tapenade-set05/v065_result.txt).

The next queue-selected row, `set05/v066` `RUN::s(mb1,mb2,mb3,mb4)`, is an
invalid-upstream closure.  Its exact generic interface is ambiguous because
specific procedures differ only by array extent, and the selected procedure
calls the generic with unmatched 10x50 and 10x70 actuals.  Exact and stored
sources fail strict compilation; fresh pinned Tapenade outputs fail the same
strict boundary; and FortAD refuses the generic call in forward and reverse
without emitting derivative source.  The independent oracle checks those
source invariants and compiler refusals, so no numerical derivative claim is
made.  See the [`case notes`](../cases/tapenade-set05/v066_notes.md) and
[`validation result`](../cases/tapenade-set05/v066_result.txt).

The next queue-selected row, `set05/v067` `RUN::s(mb1,mb2,mb3)`, is an
expected modern-Fortran refusal. The exact and stored sources use nonstandard
`REAL*8`, so strict F2018 rejects them; legacy compilation is retained only as
a control. Fresh pinned Tapenade parser, tangent, and reverse products compile
in legacy mode but reproduce the strict boundary. FortAD exact parser
extraction passes, while forward and reverse refuse the unresolved generic call
without derivative output. The independent oracle checks the compiler controls
and source invariants; no repaired source or numerical derivative claim is
made. See the [`case notes`](../cases/tapenade-set05/v067_notes.md) and
[`validation result`](../cases/tapenade-set05/v067_result.txt).

The next queue-selected row, `set05/v068` `RUN::s(mb1,mb2,mb3)`, is an
invalid-upstream closure. Its exact and stored sources call generic `FUNC`
with `real(wp)` and `REAL*8` actuals for which no specific procedure matches.
Strict and legacy exact-source compilation both fail; fresh pinned Tapenade
parser, tangent, and reverse products generate but fail both compiler controls
at the corresponding generic boundary. FortAD exact parser extraction passes,
while forward and reverse refuse the generic call without derivative output.
The independent oracle checks the generic interface, exact source invariants,
and all four compiler refusals, so no numerical derivative claim is made. See
the [`case notes`](../cases/tapenade-set05/v068_notes.md) and
[`validation result`](../cases/tapenade-set05/v068_result.txt).

The next queue-selected row, `set05/v069` `RUN::s(mb1,mb2,mb3)`, is an
invalid-upstream closure. Its exact and stored sources declare `ELEMENTAL`
procedures that execute `PRINT`, violating the implicit `PURE` contract; strict
and legacy gfortran reject both sources, with strict mode also rejecting
`REAL*8`. Fresh pinned Tapenade parser, tangent, and reverse products generate
but fail both compiler controls at the same purity boundary. FortAD at
`a41afde` refuses parser, forward, and reverse at the generic call without
emitting derivative source. The independent source/compiler oracle checks the
source invariants and all four compiler refusals, so no numerical derivative or
support claim is made. See the [`case notes`](../cases/tapenade-set05/v069_notes.md)
and [`validation result`](../cases/tapenade-set05/v069_result.txt).

The next deterministic queue shard closes four compiler-clean, no-missing-
dependency rows: `set05/v196` (`factorial`), `set05/v202` (`twice_real`),
`set06/v220` (`addvector`), and `set06/v232` (`test`). Tapenade completes the
three-mode probes. FortAD records exact parser, forward, and reverse refusal or
invalid-generated-interface boundaries: none is promoted as derivative
support. The independent oracle passes only defined primal behavior (including
central differences for the affine and constant models). It is deliberately
separate from the refusal classification. Exact source/reference hashes,
compiler-clean handoff, diagnostics, and the four status values are recorded
in the [shard manifest and result](../cases/tapenade-queue-shard-next/README.md).

The following modern-feature shard closes four more compiler-clean,
no-missing-dependency rows: `set04/ptr08` and `set04/ptr07` (`remove`),
`set06/v243` (`collect_garbage_r1`), and `set05/v180` (`fliogstc`). The exact
sources are ranked by a documented modern-feature score. Tapenade passes the
three-mode probes; FortAD records recursive pointer ownership, pointer-target
lifetime, and no-active-dependent boundaries. Independent primal/source/
refusal models pass, with no derivative-support claim. See the [modern-feature
shard manifest and result](../cases/tapenade-queue-shard-next-modern/README.md).

The next8 modern-feature shard closes four compiler-clean, no-missing-dependency
rows: `set03/cmv07`, `set10/lh234`, `set06/v237`, and `set03/cm30`. Fresh
Tapenade parser/forward/reverse probes pass for all four. FortAD records explicit
boundaries for module-owned mutable state, active derived components, module
pointers, and pointer storage identity. Independent primal, derivative, and
refusal oracles pass without claiming derivative support. See the [next8 shard
manifest and result](../cases/tapenade-queue-shard-next8/README.md).

The next9 modern-feature shard closes four compiler-clean, no-missing-dependency
rows: `set06/v290`, `set03/cm33`, `set03/lh056`, and `set03/cm26`. Fresh Tapenade
parser/forward/reverse probes pass for all four. FortAD records nested internal
procedure, module-owned mutable state, and pointer storage identity boundaries.
Independent arithmetic, pointer, and ownership oracles pass without claiming
derivative support. See the [next9 shard manifest and result](../cases/tapenade-queue-shard-next9/README.md).

The next10 through next16 modern-feature shards close twenty-eight more
compiler-clean, no-missing-dependency rows with fresh Tapenade/FortAD probes,
exact source hashes, and independent behavioral contracts. The next13 rows are
`set06/v364`, `set04/lh112`, `set03/lh051`, and `set03/cm25`; see the [next13
shard manifest and result](../cases/tapenade-queue-shard-next13/README.md). The
next14 rows are `set04/v004`, `set07/v531`, `set04/lh108`, and `set04/v048`; see
the [next14 shard manifest and result](../cases/tapenade-queue-shard-next14/README.md).
The next15 rows are `set05/v077`, `set11/vpf20`, `set10/lh230`, and
`set10/lh232`; the next16 rows are `set03/cm05`, `set03/cm10`, `set03/cm34`,
and `set03/lh013`. Next16 records three deliberate pointer/global-state
refusals and one runnable derived-type affine procedure. Next17 records the
next four queue-order set01 rows with active-I/O, character-substring,
legacy-labeled-DO, and invalid-generated-interface boundaries. See the [next16
shard](../cases/tapenade-queue-shard-next16/README.md) and [next17
shard](../cases/tapenade-queue-shard-next17/README.md). The next18 shard adds
the following four queue-order rows, `set01/lh099`, `lh101`, `lh106`, and
`lh108`, with explicit DO WHILE, COMMON/derived-storage, reverse
dependent-selection, and COMMON/undefined-storage boundaries. See the
[next18 shard](../cases/tapenade-queue-shard-next18/README.md). The next19 shard
adds the following queue-order rows `set01/lh110` through `set01/lh113`, with
independent legacy-inference, array-liveness, piecewise scalar, and invalid-DO
oracles; see its [manifest and result](../cases/tapenade-queue-shard-next19/README.md).
The next20 shard adds `set01/lh114`, `lh115`, `lh117`, and `lh118` with
dependent-inference, mutating-call, COMMON-state, and active-I/O boundaries;
see its [manifest and result](../cases/tapenade-queue-shard-next20/README.md).

The current six-case set01 closeout covers `lh093`, `lh094`, `lh097`, `lh098`,
`lh102`, and `lh103`. Each has a pinned manifest, fresh Tapenade
parser/forward/reverse generation, exact FortAD diagnostics, an independent
behavioral oracle, and three contract tests. They remain explicit
expected-refusal records rather than repaired ports: I/O boundaries, external
derivative summaries/CNKLOG, incomplete protected-expression output, and
reverse per-iteration storage.
The next six-case closeout covers `ht02`, `ht03`, `lh104`, `lh105`, `lh107`, and
`lh109`. It adds five exact refusal witnesses for unsupported I/O, active-call
boundaries, and reverse adjoint-output collisions, plus the runnable `lh107`
`MAX` sequence. All six have fresh pinned Tapenade generation, exact FortAD
probes, and independent three-test contracts.
The exact B01 closeout adds a legacy labeled-DO refusal for `GRADFB`. The
`ala03`/`ala04`/`ala05`/`bd04` closeout adds MPI-update, nested fixed-point,
DO-WHILE, and PRINT boundaries. The
four-case `B03`/`ala00`--`ala02` closeout adds one exact `COMMON` refusal
and three fixed-point `PRINT` refusal witnesses. Their pinned manifests,
fresh generation records, exact FortAD diagnostics, and independent contracts
are under `cases/tapenade-set01/`.
The `v420` large-example result is in
[`v420`](../results/tapenade_known_failure_v420_validation.txt), and the
abstract OO refusal boundary is in
[`f03typf01`](../results/tapenade_f03typf01_oo_validation.txt).
The first-aid `COMMON` refusal is in
[`validityTest.f`](../results/tapenade_first_aid_validity_refusal_validation.txt).
The set01 `lh054`--`lh061` tranche records six additional exact-source
boundaries. Tranche X (`lh063`, `lh064`, `lh065`, `lh067`, `lh069`, and
`lh070`) adds four bounded fixed-form witnesses plus two invalid-upstream
closures. Tranche Y (`lh071`, `lh072`, `lh073`, `lh075`, `lh076`, and `lh077`)
adds two invalid-upstream closures and four bounded refusal witnesses. Each has
fresh pinned Tapenade generation, exact FortAD diagnostics, and a three-test
case contract; bounded ports are not exact-source support claims.

The historical-reference tranche Z (`todoF90/REFERENCES/bd01`, `bd11`, `v01`,
`v02`, `v05`, and `v07`) adds four exact-source refusal witnesses with bounded
module, array-section, or explicit-state ports, plus two invalid-upstream
closures. Each case records fresh Tapenade generation, exact FortAD diagnostics,
and a three-test contract; bounded ports remain explicitly scoped.

Tranche AA (`todoF90/REFERENCES/v100`, `v101`, `v144`, `v270`, `v322`, and
`v377`) adds two bounded refusal witnesses and four invalid-upstream closures.
The cases cover MOD, allocatable lifetime, implicit-interface/rank, legacy-kind,
derived-type-state, and MPI communication boundaries with fresh Tapenade and
FortAD evidence.

Tranche AB (`todoF90/REFERENCES/v385`, `v402`, `v412`, `v413`, `v414`, and
`v415`) adds three invalid-upstream closures and three expected-refusal
boundaries. The cases cover MPI/allocatable state, invalid calls and missing
runtime dependencies, mixed-kind interfaces, undefined local state, private
derived types, and allocatable components. Each has fresh pinned Tapenade
generation, exact FortAD evidence, and an independent three-test contract.

Tranche AC (`todoF90/REFERENCES/v416`, `v417`, `v418`, `v419`, `v421`, and
`v422`) adds one bounded declaration-order witness, three expected-refusal
boundaries, and two invalid-upstream closures. The cases cover declaration
order, allocatable components, MPI interfaces, assumed-size/context state,
explicit-shape actuals, and undefined function results. Each has fresh pinned
Tapenade generation, exact FortAD evidence, and an independent three-test
contract.

Tranche AD (`todoF90/REFERENCES/v425`, `v426`, `v427`, `v469`, `v500`, and
`v503`) adds one bounded strict-tab witness, four expected-refusal boundaries,
and one incomplete invalid-upstream closure. The cases cover module parsing,
allocatable lifetimes and module state, `DATA`, singular normalization, and
missing project context. Each has fresh pinned Tapenade generation, exact
FortAD evidence, and an independent three-test contract.

Tranche AE (`todoF90/REFERENCES/v504`, `v505`, `v508`, `v519`, `v526`, and
`v547`) adds two bounded ports and four expected-refusal boundaries. The cases
cover procedure-interface collisions, external callbacks, `inout` and global
state, standalone programs, module bundles with allocation, and legacy binding
labels. Each has fresh pinned Tapenade generation, exact FortAD evidence, and
an independent three-test contract.

Tranche AF (`nonRegressions/set01/lh000`, `set02/v065`, `set04/v017`,
`set04/v025`, `set05/v075`, and `set05/v146`) closes six no-entry-point
candidate rows. The cases cover empty sources, `BLOCKDATA`, and module-only
declarations with stored parser references. Each has fresh pinned Tapenade
no-root evidence, an exact FortAD boundary where applicable, and an independent
three-test semantic contract; no synthetic procedure is introduced.

Tranche AG (`set05/v147`, `set05/v171`, `set05/v177`, `set05/v201`,
`set05/v216`, `set06/v316`, `set06/v317`, `set06/v320`, `set06/v360`,
`set06/v362`, `set07/v485`, `set07/v523`, `set07/v544`, and `set11/vpf16`)
closes the remaining fourteen no-entry-point queue rows. The cases cover
declaration-only modules, invalid legacy declarations, pointers, private and
derived-type layouts, an empty source, and the `vpf16` `Options` metadata.
Each has fresh pinned Tapenade no-root evidence, strict source/reference
checks, quiet FortAD no-entry behavior, and an independent three-test contract.

Tranche AH (`set01/lh136`, `set01/lh144`, `set02/lh192`, and the modern
`set12` trio `cmplxstep01`, `f03typf01`, and `f03fptr01`) adds five new ledger
closures. The cases cover an unsupported fixed-form declaration, a generated
reverse-signature collision, reverse checkpoint storage, mutable module state,
abstract deferred dispatch, and procedure-pointer aliasing. Each has pinned
source hashes, fresh Tapenade generation, exact FortAD results, and an
independent arithmetic or finite-difference oracle. The modern three-case
record is [here](../cases/tapenade-set12/modern-tranche-a.md). The profile
tranche adds `set12/jlb012` and `set12/profile01`: the former is an exact
free-form expected refusal at strict generated compilation, while the latter
passes FortAD forward/reverse generation, strict compilation, runtime, and
the independent hand/finite-difference/adjoint oracle. See
[`cases/tapenade-set12-profile-tranche`](../cases/tapenade-set12-profile-tranche/README.md).

## Closeout rule

The committed ledger contains all 2,014 candidate paths. Its language and
source-form columns are filename hints generated from Git-tracked files. A `|`
separates languages when a candidate contains more than one. The component
classification comes from the manifest. These fields locate work. They do not
show that a source parses, compiles, runs, or differentiates.

Every untriaged row still needs a checked entry point, Tapenade options,
derivative modes, oracle, dependencies, and results for Tapenade and FortAD. A runnable
numerical case also gets transformation time, compile time, runtime, peak
memory, and generated-source size for each applicable engine. Until that work
is recorded, the row remains `untriaged` with both results set to `not-run`.

The manifest-aware source workflow in
[`scripts/probe_tapenade_fortad.py`](../scripts/probe_tapenade_fortad.py) turns
that triage into repeatable parser/forward/reverse probes. It accepts an
existing case manifest or a queue case, writes generated products and complete
stdout/stderr diagnostics, and emits JSON records. For the pure-Fortran corpus,
use `--pure-fortran`; queue rows are sorted by `(component, path)` before
round-robin sharding, so `queue_rank` changes cannot strand a whole category on
one worker. Each shard writes its own
`results.shard-NNNN-of-NNNN.jsonl` file and updates it atomically after every
completed probe. Rerun with `--resume` after an interruption, then combine all
shards with `--merge-input`; the merge checks that every discovered entry-point
probe is present exactly once and writes a deterministic, sorted `results.jsonl`.
Queue mode expands every canonical source procedure discovered by static
triage, records each root separately, and emits explicit
`ambiguous-entry-point`, `source-selection-error`, and dependency-risk fields
without running a transform when source or entry selection is unsafe.
`--all-entry-points` provides the same behavior for a single case. The
workflow never guesses active or dependent arguments, and each record still
needs an independent numerical contract before its ledger status changes.

For example, run and resume eight pure-Fortran shards with separate output
directories, then merge them:

```bash
scripts/probe_tapenade_fortad.py --queue --pure-fortran \
  --shard-count 8 --shard-index 0 --jobs 4 --resume \
  --result-dir results/tapenade-probes/shard-0
scripts/probe_tapenade_fortad.py --queue --pure-fortran \
  --merge-input results/tapenade-probes/shard-0/results.shard-0000-of-0008.jsonl \
  --merge-input results/tapenade-probes/shard-1/results.shard-0001-of-0008.jsonl \
  --result-dir results/tapenade-probes/merged
```

The merge command should list all eight shard files. The queue and compiler
batch reports remain evidence-neutral: compiler-clean or dependency-risk rows
are handoff signals, not Tapenade, FortAD, runtime, or derivative-correctness
claims.

Fortran cases close only after all valid differentiable paths work in FortAD
and pass an independent oracle. Invalid programs and cases that require an
unavailable external library get a reproducible classification. C, C++, and
Julia inputs remain in the ledger so cross-engine coverage cannot omit them or
count them as FortAD wins.

Tapenade is MIT-licensed at the pinned revision. The checkout remains upstream
material. Any port committed under `cases/` must retain the upstream notice and
add a row to [`../PROVENANCE.md`](../PROVENANCE.md).
