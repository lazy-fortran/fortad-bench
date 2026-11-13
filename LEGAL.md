# Legal and distribution policy for fortad-bench

This repository builds and runs a large number of third-party automatic
differentiation engines. It follows the same rule as
[fortad](https://github.com/lazy-fortran/fortad), whose
[LEGAL.md](https://github.com/lazy-fortran/fortad/blob/main/LEGAL.md) is the
governing document. This file records the benchmark-specific rules.

**This is not legal advice.** It records the project's engineering policy.

## 1. Harness and external engines

The original fortad-bench harness is MIT licensed. Competing engine source
and build trees are fetched into ignored directories by `scripts/` and are
not distributed with it. Ported workload sources are the exception: they
retain their upstream licences and notices as listed in [PROVENANCE.md](PROVENANCE.md)
and `LICENSES/`. Tapenade ports use MIT; sources reused from
differentiable-fortran use Apache-2.0.

Benchmark *results* (timings, memory, generated-code size, engine version) are
measurements we made. They are facts about our machine and they are committed.
Engine *code* is not.

## 2. Copyleft engines run at arm's length

CoDiPack (GPL-3), Clad (LGPL), ColPack (LGPL), CasADi (LGPL), SU2 (LGPL) and
similar are built as **separate programs or separate builds** and invoked as
subprocesses. The harness invokes these builds through their command-line interfaces.
Engine binaries and source trees are excluded from the distributed harness;
any separate distribution must retain the terms of the engine concerned.

An adapter under `engines/` may contain the build recipe and the command line for
such an engine. It may not contain the engine's code, and it may not contain code
derived by reading the engine's source rather than its documentation.

## 3. Ported workloads

A case ported from an upstream corpus:

- comes only from a permissively licensed corpus (ADBench is MIT, MITgcm is MIT,
  VMEC++ is MIT, and Tapenade is MIT at the pinned corpus revision),
- retains the upstream copyright notice in the ported file's header,
- gets a `PROVENANCE.md` row naming the upstream revision, files, licence, and
  every deviation.

LGPL and GPL corpora (SU2) are **run as black boxes**, never ported. Corpora with
no discoverable licence are not used at all.

`scripts/fetch_upstreams.py --corpus tapenade` places the unmodified Tapenade
checkout and its generated filename inventory under gitignored paths. Fetching
does not make those files part of fortad-bench. A Tapenade case enters `cases/`
only with its copyright notice and a `PROVENANCE.md` row.

## 4. Fair configuration is a legal-adjacent obligation too

Publishing a benchmark that misrepresents another project is a reputational and
occasionally a legal problem. Every engine is configured to its documented best
practice, its version is recorded, and where we are unsure we have configured it
well, the result says so. See [the comparison rules](docs/benchmarks.md#rules-for-a-number-to-count).

## 5. Contributor checklist

1. No third-party source is added except a documented workload port with its licence and notice.
2. No engine source tree is inside a committed path.
3. Any ported workload has its `PROVENANCE.md` row and upstream notice.
4. Any published comparison names the engine version and the flags used.

## 6. Metadata-only sources

“Not legally scannable” is project shorthand, not a legal classification. It
means that automated fetching or source inspection is outside our permission or
cannot be verified safely. Examples are registration-gated distributions,
confidential or access-controlled code, a source URL whose terms forbid
automated copying, historical archives with no clear licence, and repositories
with no discoverable licence. For these entries we keep only public metadata:
name, URL, version or date, licence status, and the reason source inspection is
excluded. We do not clone, read, quote, adapt, or place a checkout in the
benchmark. A later licence grant must be recorded before inspection begins.
