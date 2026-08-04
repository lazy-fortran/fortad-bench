# Legal and distribution policy for fortad-bench

This repository builds and runs a large number of third-party automatic
differentiation engines. It follows the same rule as
[fortad](https://github.com/lazy-fortran/fortad), whose
[LEGAL.md](https://github.com/lazy-fortran/fortad/blob/main/LEGAL.md) is the
governing document. What follows is the part specific to benchmarking.

**This is not legal advice.** It records the project's engineering policy.

## 1. Nothing third-party is redistributed

fortad-bench is MIT licensed and contains only its own work. Competing engines,
their sources, and their build trees are fetched locally into gitignored
directories by `scripts/`, and never committed, released, or shipped in a
container image.

Benchmark *results* — timings, memory, generated-code size, engine version — are
measurements we made. They are facts about our machine and they are committed.
Engine *code* is not.

## 2. Copyleft engines run at arm's length

CoDiPack (GPL-3), Clad (LGPL), ColPack (LGPL), CasADi (LGPL), SU2 (LGPL) and
similar are built as **separate programs or separate builds** and invoked as
subprocesses. No fortad or fortad-bench binary links them. There is therefore no
combined work and no licence obligation propagating into this repository.

An adapter under `engines/` may contain the build recipe and the command line for
such an engine. It may not contain the engine's code, and it may not contain code
derived by reading the engine's source rather than its documentation.

## 3. Ported workloads

A case ported from an upstream corpus:

- comes only from a permissively licensed corpus (ADBench is MIT, MITgcm is MIT,
  VMEC++ is MIT),
- carries the upstream copyright notice in the ported file's header,
- gets a `PROVENANCE.md` row naming the upstream revision, files, licence, and
  every deviation.

LGPL and GPL corpora (SU2) are **run as black boxes**, never ported. Corpora with
no discoverable licence are not used at all.

## 4. Fair configuration is a legal-adjacent obligation too

Publishing a benchmark that misrepresents another project is a reputational and
occasionally a legal problem. Every engine is configured to its documented best
practice, its version is recorded, and where we are unsure we have configured it
well, the result says so. See README rule 4.

## 5. Contributor checklist

1. `git status --porcelain` shows no third-party source.
2. No engine source tree is inside a committed path.
3. Any ported workload has its `PROVENANCE.md` row and upstream notice.
4. Any published comparison names the engine version and the flags used.
