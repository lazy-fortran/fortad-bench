# Workload and method provenance

Every case and every measurement method has a row here before it has an
implementation. See [LEGAL.md](LEGAL.md) for the rules this table enforces.

## Cases

| Case | Mathematical statement | Upstream | Licence | Ported | Independent oracle |
|---|---|---|---|---|---|
| `vmec-jacobian` | half-grid metric quantities and Jacobian `tau` from full-grid geometry; `tau` nonlinear in the geometry | VMEC++ `vmec/ideal_mhd_model/jacobian_kernel.h`, commit `ccdeec53` | MIT, Proxima Fusion | ported in `cases/vmec-jacobian/kernel.f90`; Fortran arrays replace flat buffers and fixed zero-based offsets; upstream notice retained | hand-derived JVP/VJP, central-difference step sweep, adjoint identity |
| `heat1d` | one explicit step of the 1D heat equation | `lazy-fortran/differentiable-fortran` `docs/contract.md` | MIT, this project | reused | analytical JVP and VJP already in that repository |
| `fortnum-kernels` | per-kernel, stated in fortnum | `lazy-fortran/fortnum` | MIT, this project | reused | existing `analytical` candidates and committed baselines |
| `tapenade-set01` lh001, lh023, lh032, lh049, lh134, lh057, lh058, lh068, lh088; lh066 and bd06 refusals | `o1=35*i1*i2**2/(i1-3*i2)`, with `o2=35` and final `o3=2` after the upstream in-place writes; `c=b*b+a/100`; `y=2*x**2`; `z=3*(x*y)**2+x` followed by `y=2*x`; `f=log(-x)` for `x<0`; `a_out=b*sqrt(a*c)` and `c_out=sqrt(a_out**2+b**2+c**2)`; `e=sqrt(sum((t-u)**2))`; `min(0,c(i)*a(i-2)+b(i+5))` at `i=3,7`; `sqrt(b)+log(c)+c**d`; lh066 and bd06 mutate outputs in place | Tapenade `nonRegressions/set01/{lh001,lh023,lh032,lh049,lh134,lh057,lh058,lh068,lh088,lh066,bd06}/program.f`, commit `e59864c` | MIT, INRIA | ports in `cases/tapenade-set01`; explicit names, intents, and `real64` kinds; lh001 retains the external sub1 call and in-place state while defining the initial independent state; lh049 retains the nonlinear intermediate and in-place `y` update; lh057 splits in-place results for distinct reverse seeds; lh058 uses an explicit nonzero-norm domain; lh068 splits the two overwritten values into scalar outputs and tests both min branches; lh088 adds only an aggregate output for scalar reverse seeding; lh066 and bd06 exact in-place reverse are explicit refusals | hand JVP/VJPs, four-step central differences, adjoint identities; gfortran compile and FortAD diagnostics for refusals |
| `adbench` GMM, BA, hand, LSTM | as published with the suite | `microsoft/ADBench` | MIT | planned, with upstream notice | suite's own reference derivatives, plus finite differences |
| `solve-heavy` | Newton solve and a contractive fixed-point iteration | original, written from the mathematics | n/a | n/a | implicit function theorem derivative, derived by hand |
| `sparse` | Jacobians and Hessians with banded and arrowhead structure | original | n/a | n/a | dense evaluation of the same derivative |
| `scaling` | synthetic sweeps in input, output, and direction count | original | n/a | n/a | analytical, by construction |

## Fetched corpora

| Corpus | Upstream revision | Licence | Local scope | Committed here |
|---|---|---|---|---|
| Tapenade | `tapenade/tapenade` `e59864cab441d4175df75383b3ff58c3dcd26df9` | MIT, INRIA | full 10,977-file checkout with 2,014 candidates inventoried by `docs/corpora/tapenade.toml` | manifest plus nine attributed set01 ports and two explicit refusals; upstream checkout and generated inventories remain gitignored |

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
| Tapenade | separate program, source in / source out | MIT | no |
| Clad | Clang plugin, separate build | LGPL | no |
| CoDiPack | separate build | GPL-3 | **never** |
| ADOL-C | separate build | EPL-2.0 / GPL-2.0 | no |
| Adept | separate build | Apache-2.0 | no |
| Sacado | separate build | BSD-3-Clause | no |
| JAX, PyTorch | separate Python environment | Apache-2.0, BSD-3-Clause | no |
| Enzyme.jl, Mooncake.jl, ForwardDiff.jl | separate Julia environment | MIT | no |
