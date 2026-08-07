# Pure-Fortran Tapenade batch manifest

This report joins static and compiler evidence for `1,354` pure-Fortran candidates from a `1,428`-row queue. Mixed-language candidates are excluded.

It is an evidence-only handoff. `compiler-clean` means each listed source was accepted by the recorded syntax-only compiler (apart from include fragments, which are not standalone units). It does not claim Tapenade parsing, FortAD support, linking, runtime behavior, or derivative correctness.

Regenerate and check it with:

```bash
scripts/batch_tapenade_fortran.py
scripts/batch_tapenade_fortran.py --check
```

## Candidate status

| status | candidates |
|---|---:|
| `compiler-clean` | 579 |
| `compiler-errors` | 499 |
| `compiler-missing-dependency` | 276 |

## Compiler file status

| status | files |
|---|---:|
| `compiled` | 2052 |
| `include-fragment-not-compiled` | 125 |
| `syntax-error` | 1516 |

Candidates without a static entry-point hint: **21**.
Each row carries the exact source paths, sorted entry-point hints, compiler diagnostic hashes, missing/extra source paths, and a bounded `next_action`. No row changes the status ledger.
