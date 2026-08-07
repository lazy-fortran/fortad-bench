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
  either engine. It leaves 1,402 pure Fortran and 74 mixed-language rows
  untriaged, while preserving twenty-six set01 evidence rows and four additional
non-set01 evidence cases.

Build the next-tranche queue without changing those ledger statuses:

```bash
scripts/queue_tapenade_fortran.py
scripts/queue_tapenade_fortran.py --check
```

[`corpora/tapenade-fortran-queue.jsonl`](corpora/tapenade-fortran-queue.jsonl)
and its [summary](corpora/tapenade-fortran-queue.md) partition the 1,476 rows
into 74 mixed-language-risk candidates, 36 historical-failure candidates, 20
rows with no entry-point hint, 318 program candidates, and 1,031 procedure
candidates. An orthogonal `missing-dependency-risk` category covers 170 rows
with non-local include hints. The queue uses only static filename and line-based
declaration/include/use hints. An unresolved include is reported as a
dependency risk signal, not as proof that a dependency is missing. No queue
label claims parsing, compilation, transformation, runtime, or correctness.

Run the compiler-backed evidence pass after fetching the pinned checkout:

```bash
scripts/triage_tapenade_fortran.py --jobs 4
scripts/triage_tapenade_fortran.py --check
```

[`corpora/tapenade-fortran-compiler.jsonl`](corpora/tapenade-fortran-compiler.jsonl)
and its [summary](corpora/tapenade-fortran-compiler.md) contain one stable row
per queued candidate and one status/hash record per tracked Fortran source.
Fixed/free source forms get strict syntax-only flags and local include roots;
`.inc`/`.fh` fragments are listed as evidence but not compiled alone. A
`compiled` status is only compiler acceptance, never a transformation or
derivative-support claim. Use `--shard-index`/`--shard-count` for independent
workers and `--merge-input` to produce the same sorted report from shards.

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
The `v420` large-example result is in
[`v420`](../results/tapenade_known_failure_v420_validation.txt), and the
abstract OO refusal boundary is in
[`f03typf01`](../results/tapenade_f03typf01_oo_validation.txt).
The first-aid `COMMON` refusal is in
[`validityTest.f`](../results/tapenade_first_aid_validity_refusal_validation.txt).

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

Fortran cases close only after all valid differentiable paths work in FortAD
and pass an independent oracle. Invalid programs and cases that require an
unavailable external library get a reproducible classification. C, C++, and
Julia inputs remain in the ledger so cross-engine coverage cannot omit them or
count them as FortAD wins.

Tapenade is MIT-licensed at the pinned revision. The checkout remains upstream
material. Any port committed under `cases/` must retain the upstream notice and
add a row to [`../PROVENANCE.md`](../PROVENANCE.md).
