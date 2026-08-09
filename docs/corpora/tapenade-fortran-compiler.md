# Tapenade compiler-backed Fortran triage

This report covers `929` of `929` queued candidates (`full queue`). It runs each tracked Fortran source as an individual `gfortran -fsyntax-only -std=f2018 -pedantic-errors` check. A `compiled` row is compiler acceptance only. It is not evidence that Tapenade, FortAD, a runtime, or derivatives work.

The checkout is the pinned Tapenade revision named in `docs/corpora/tapenade.toml`. Source form is selected by suffix (`.f`/`.for` fixed, `.f90`/`.f03`/similar free). Candidate-local source/include directories and the checkout root are passed as `-I` roots. Paths, command flags, and diagnostic hashes are deterministic. Compiler identity is recorded explicitly because diagnostics can vary by compiler release.

Regenerate the full report:

```bash
scripts/fetch_upstreams.py tapenade
scripts/triage_tapenade_fortran.py --jobs 1
scripts/triage_tapenade_fortran.py --check
```

## File status

| status | files |
|---|---:|
| `compiled` | 1166 |
| `include-fragment-not-compiled` | 74 |
| `syntax-error` | 1372 |

## Failure kind

| kind | files |
|---|---:|
| `compiler-diagnostic` | 842 |
| `include-fragment-not-compiled` | 74 |
| `missing-dependency` | 530 |
| `none` | 1166 |

## Source kinds

| kind | files |
|---|---:|
| `fixed` | 706 |
| `free` | 1832 |
| `include-fragment` | 74 |

`syntax-error`, `missing-source`, `checkout-missing`, `timeout`, and `compiler-unavailable` are evidence statuses, not support/refusal classifications. A `missing-dependency` failure is inferred only from compiler diagnostic text (`include`/`module` open failures). It is not a claim that the dependency is absent. Include fragments are listed but intentionally not compiled as standalone translation units. Each source is checked independently, so a sibling `use` without a pre-existing local `.mod` is reported as dependency evidence rather than silently treated as a candidate-level failure or success.

Compiler: `gfortran`. The checkout path is intentionally omitted from this summary so copies of the pinned checkout remain comparable. Diagnostic hashes are SHA-256 of normalized compiler output. An empty diagnostic has the SHA-256 empty-string hash.

Rows are sorted by candidate identity and each file list is sorted by source path. They contain no temporary or absolute paths, so shard reports can be merged with `--merge-input` without depending on worker completion order.
