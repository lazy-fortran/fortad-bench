# Tapenade Fortran queue

This is a deterministic, evidence-neutral queue for the currently untriaged rows (1,077 candidates). It reads only the committed static triage and status ledger. It does not run a compiler, Tapenade, FortAD, or an oracle.

Regenerate and check it with:

```bash
scripts/queue_tapenade_fortran.py
scripts/queue_tapenade_fortran.py --check
```

## Queue buckets

The first matching rule wins:

1. `mixed-language-risk`: the filename language hint contains Fortran and another language.
2. `parser-or-invalid-risk`: the manifest marks the row as a historical Fortran issue/expected-failure component. This does not prove a parser failure.
3. `reference-only-evidence`: every detected Fortran source name is derivative-shaped and no entry hint was found.
4. `no-entry-point-evidence`: the extractor found no program, subroutine, or function hint. This is not proof that no entry point exists.
5. `runnable-program-candidate`: a program declaration hint was found.
6. `runnable-procedure-candidate`: a subroutine/function declaration hint was found.
7. `needs-static-inspection`: residual rows that do not match these rules.

| queue bucket | rows |
|---|---:|
| `mixed-language-risk` | 74 |
| `parser-or-invalid-risk` | 0 |
| `reference-only-evidence` | 0 |
| `no-entry-point-evidence` | 0 |
| `runnable-program-candidate` | 237 |
| `runnable-procedure-candidate` | 766 |
| `needs-static-inspection` | 0 |

## Language and dependency signals

| language hint | rows |
|---|---:|
| `c++|fortran` | 2 |
| `c|fortran` | 72 |
| `fortran` | 1003 |

`112` rows carry the orthogonal `missing-dependency-risk` category because an include target's basename is not present among that candidate's tracked source/include files. This is a dependency risk signal, not proof that the dependency is absent. System headers and shared runtime files may be supplied externally.

Most frequent unresolved include hints:

- `adStack.h` (52 rows)
- `stdio.h` (39 rows)
- `adContext.h` (26 rows)
- `DIFFSIZES.inc` (17 rows)
- `ampi/ampif.h` (15 rows)
- `math.h` (10 rows)
- `admpif.h` (10 rows)
- `stdlib.h` (5 rows)
- `globals.inc` (3 rows)
- `string.h` (2 rows)
- `stdarg.h` (1 rows)
- `iostream` (1 rows)

## Interpretation

The program/procedure buckets identify the next candidates for actual entry-point inspection and compiler-backed runs. The mixed and historical-failure buckets should be isolated first so a missing C/C++ boundary or known Tapenade failure is not mistaken for a FortAD result. Static hints include checked-in reference derivatives, can miss multiline declarations, and do not resolve modules or build systems. Every row remains `untriaged` until a compiler, transformation, runtime, and independent oracle provide evidence in the status ledger.

The machine-readable rows are in `tapenade-fortran-queue.jsonl`.
