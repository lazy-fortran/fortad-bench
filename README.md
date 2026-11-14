# fortad-bench

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24223535.svg)](https://doi.org/10.5281/zenodo.24223535)

Correctness and performance workloads for
[fortad](https://github.com/lazy-fortran/fortad), with comparisons against
Enzyme, Tapenade and other automatic differentiation tools. Each result records
the workload, compiler, engine revision, flags and an independent correctness
check. Recorded timings describe that configuration; they are not universal
performance claims.

The suite includes small analytical kernels, numerical kernels from
[fortnum](https://github.com/lazy-fortran/fortnum) and
[fortfem](https://github.com/lazy-fortran/fortfem), a VMEC++ geometry port,
controlled Enzyme-inspired workloads, and Tapenade corpus cases. Unsupported
language constructs and failed builds are recorded explicitly.

## Getting started

Requirements depend on the selected engine. The corpus and audit scripts need
Python 3.11 or later and Git; compiled checks need a Fortran compiler. Enzyme
requires a matching LLVM toolchain and plug-in, and Tapenade requires Java.
Their build scripts are under `scripts/`.

```console
git clone https://github.com/lazy-fortran/fortad-bench.git
cd fortad-bench
python3 scripts/fetch_upstreams.py --corpus tapenade
python3 scripts/fetch_upstreams.py --audit-corpora
python3 -m unittest discover -s scripts -p 'test_*.py'
```

Competing tool sources and build trees remain in ignored directories. A source
fetch does not run the complete benchmark or establish derivative correctness.

To build the plotting programs, install the Fortran Package Manager (fpm) and
run `fpm build` with a Fortran compiler.
`fpm.toml` pins [fortplot](https://github.com/lazy-fortran/fortplot); no sibling
checkout is required. Scripts that transform sources use a separate fortad
checkout selected by `FORTAD_REPO`.

## Documentation and data

- [User guide and layout](docs/README.md)
- [Workloads, measurement methods and recorded comparisons](docs/benchmarks.md)
- [Tapenade corpus guide](docs/tapenade-corpus.md)
- [Origin, licences and changes to ported sources](PROVENANCE.md)
- [Publication list](docs/reading-list.md) and [BibTeX](docs/bibliography.bib)

`cases/` contains workload source and independent oracles; `harness/` contains
compiled drivers; `engines/` contains engine interfaces; `results/` contains
measurements. The exact-source Tapenade records and their inventories are
collected under `cases/tapenade-exact/`.

## Verification and limits

Derivative checks use analytical derivatives, finite-difference step sweeps,
and adjoint identities. Agreement with another differentiation tool is supporting
evidence. Passing a parser probe or compiling generated code is recorded
separately from a runtime derivative check.

Engine availability and language support vary by workload. The full compiler
matrix requires compilers that may be absent on a local machine; a missing
compiler is reported rather than counted as a pass. The measured comparisons
include workloads where fortad is slower. Consult each result's recorded
configuration before reusing its numbers.

## Licence

The original harness uses MIT. Tapenade source ports retain INRIA's MIT notices;
reused differentiable-fortran sources retain Apache-2.0. Full texts and notices
are in [LICENSES](LICENSES), with source mappings in [PROVENANCE.md](PROVENANCE.md).

## Citation

Cite fortad-bench through its Zenodo record,
[doi:10.5281/zenodo.24223535](https://doi.org/10.5281/zenodo.24223535), which
always resolves to the latest release; release 0.1.0 is
[doi:10.5281/zenodo.24223536](https://doi.org/10.5281/zenodo.24223536).
`CITATION.cff` holds the full citation metadata.
