# Workload and method provenance

Every case and every measurement method has a row here before it has an
implementation. See [LEGAL.md](LEGAL.md) for the rules this table enforces.

## Cases

| Case | Mathematical statement | Upstream | Licence | Ported | Independent oracle |
|---|---|---|---|---|---|
| `vmec-jacobian` | half-grid metric quantities and Jacobian `tau` from full-grid geometry; `tau` nonlinear in the geometry | VMEC++ `vmec/ideal_mhd_model/jacobian_kernel.h` | MIT, Proxima Fusion | planned, with upstream notice | hand-derived JVP/VJP, central differences, adjoint identity |
| `heat1d` | one explicit step of the 1D heat equation | `lazy-fortran/differentiable-fortran` `docs/contract.md` | MIT, this project | reused | analytical JVP and VJP already in that repository |
| `fortnum-kernels` | per-kernel, stated in fortnum | `lazy-fortran/fortnum` | MIT, this project | reused | existing `analytical` candidates and committed baselines |
| `adbench` GMM, BA, hand, LSTM | as published with the suite | `microsoft/ADBench` | MIT | planned, with upstream notice | suite's own reference derivatives, plus finite differences |
| `solve-heavy` | Newton solve and a contractive fixed-point iteration | original, written from the mathematics | — | n/a | implicit function theorem derivative, derived by hand |
| `sparse` | Jacobians and Hessians with banded and arrowhead structure | original | — | n/a | dense evaluation of the same derivative |
| `scaling` | synthetic sweeps in input, output, and direction count | original | — | n/a | analytical, by construction |

## Measurement method

| Quantity | Method | Source |
|---|---|---|
| Complete-workload wall clock | best of N repetitions after warm-up, N and warm-up recorded | `differentiable-fortran` `docs/benchmark-method.md` |
| Peak resident memory | `/usr/bin/time -v` maximum resident set, cross-checked against `getrusage` | standard |
| Tape / checkpoint bytes | engine-reported where available, else peak RSS delta over the primal | per-engine, recorded |
| Build time | wall clock, split into toolchain setup, AD transformation, and compilation | original |
| Incremental rebuild | wall clock after a one-line change to the primal | original |
| Generated-code size | bytes of emitted source and of the resulting object | original |
| Vectorisation | compiler's own report, parsed; `-fopt-info-vec` and equivalents | per-compiler |
| Adjoint identity check | `⟨u, Jv⟩ = ⟨Jᵀu, v⟩` on random `u`, `v`, tolerance recorded | standard |
| Finite-difference check | central differences with a step-size convergence test, not a single step | Griewank & Walther 2008 |

## Engines

Engine versions and revisions are recorded per result file, not here. This table
records only how each engine is reached and under what terms.

| Engine | Reached by | Licence | Linked into our binaries |
|---|---|---|---|
| fortad | in-process | MIT | yes |
| analytical, finite differences | in-process | MIT, ours | yes |
| Enzyme (flang-new, LFortran, Clang) | compiler plugin, separate build | Apache-2.0 with LLVM exception | no |
| Tapenade | separate program, source in / source out | Inria terms | no |
| Clad | Clang plugin, separate build | LGPL | no |
| CoDiPack | separate build | GPL-3 | **never** |
| ADOL-C | separate build | EPL-2.0 / GPL-2.0 | no |
| Adept | separate build | Apache-2.0 | no |
| Sacado | separate build | BSD-3-Clause | no |
| JAX, PyTorch | separate Python environment | Apache-2.0, BSD-3-Clause | no |
| Enzyme.jl, Mooncake.jl, ForwardDiff.jl | separate Julia environment | MIT | no |
