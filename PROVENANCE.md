# Workload and method provenance

Ported workload sources retain their original licences and notices. The
source records below distinguish upstream code, adapted code and original
mathematical variants. See [LEGAL.md](LEGAL.md) for the distribution policy.

A Jacobian-vector product (JVP) applies a derivative to an input direction; a
vector-Jacobian product (VJP) applies its transpose to an output seed.

## Cases

| Case | Mathematical statement | Upstream | Licence | Ported | Independent oracle |
|---|---|---|---|---|---|
| `vmec-jacobian` | half-grid metric quantities and Jacobian `tau` from full-grid geometry; `tau` nonlinear in the geometry | VMEC++ `vmec/ideal_mhd_model/jacobian_kernel.h`, commit `ccdeec53` | MIT, Proxima Fusion | ported in `cases/vmec-jacobian/kernel.f90`; Fortran arrays replace flat buffers and fixed zero-based offsets; upstream notice retained | hand-derived JVP/VJP, central-difference step sweep, adjoint identity |
| `heat1d` | one explicit step of the 1D heat equation | `lazy-fortran/differentiable-fortran` `docs/contract.md` | Apache-2.0 | planned; no implementation is distributed here | analytical JVP and VJP in the source project |
| `fortnum` and `fortfem` | numerical operators listed below | source snapshots and paths below | MIT, notices retained | batched scalar objectives and C interfaces | sampled-coordinate central differences, contraction checks and cross-engine comparisons; details below |
| `tapenade-set01` lh001, lh002, lh019, lh023, lh032, lh049, lh057, lh058, lh068, lh088, lh134; lh004, lh066, and bd06 refusals | `lh001: o1=35*i1*i2**2/(i1-3*i2)`, with `o2=35` and final `o3=2` after the upstream in-place writes; `lh002: x>0: x_final=1.7+5.1*z_initial, y_final=1.7, z_final=5.1*z_initial; x<0: x_final=x_initial, y_final=3.3*x_initial**2, z_final=z_initial; a_final=3.7*b_initial`; `lh023: c=b*b+a/100`; `lh032: y=2*x**2`; `lh049: z=3*(x*y)**2+x` followed by `y=2*x`; `lh134: f=log(-x)` for `x<0`; `lh057: a_out=b*sqrt(a*c)` and `c_out=sqrt(a_out**2+b**2+c**2)`; `lh058: e=sqrt(sum((t-u)**2))`; `lh068: min(0,c(i)*a(i-2)+b(i+5))` at `i=3,7`; `lh088: sqrt(b)+log(c)+c**d`; `lh004` fixed trace `x1=4*abs(z), x2=4*y`; `lh019` active `real8_diff` component with passive integer tag | Tapenade `nonRegressions/set01/{lh001,lh002,lh004,lh019,lh023,lh032,lh049,lh057,lh058,lh068,lh088,lh066,lh134,bd06}/program.f`, commit `e59864c` | MIT, INRIA | ports in `cases/tapenade-set01`; explicit names, intents, and `real64` kinds; lh001 retains the external sub1 call and in-place state while defining the initial independent state; lh002 retains the branch, nested sub1 calls, and final state; lh004 keeps the guarded bounded loop for an independent fixed-trace oracle, with reverse control-flow refusal recorded; lh019 checks scalarized active components through FortAD while keeping the tag passive; lh049 retains the nonlinear intermediate and in-place `y` update; lh057 splits in-place results for distinct reverse seeds; lh058 uses an explicit nonzero-norm domain; lh068 splits the two overwritten values into scalar outputs and tests both min branches; lh088 adds only an aggregate output for scalar reverse seeding; lh004, lh066, and bd06 exact reverse boundaries are explicit refusals | hand JVP/VJPs, four-step central differences, adjoint identities; gfortran compile and FortAD diagnostics for refusals |
| `tapenade-set05` v150 and v168 | `v150: f=exp(t*t)`; `v168: y=abs(abs(2*x)-4)*abs(2*x)` with the overwritten intermediate represented locally | Tapenade `nonRegressions/set05/{v150,v168}/program.f90`, commit `e59864c` | MIT, INRIA | standards-clean ports in `cases/tapenade-set05`; active maps retained with explicit `real64` kinds and intents | hand JVP/VJPs, three-step central differences, adjoint identities; strict exact/reference and fresh Tapenade generated-source compilation; FortAD JVP/VJP compilation and runtime |
| `tapenade-set06` v314 and v379 | `v314: x=y+z*z`; `v379: f=sqrt(sum(x)**2)` on a positive-sum domain with dynamic input shape | Tapenade `nonRegressions/set06/{v314,v379}/program.f90`, commit `e59864c` | MIT, INRIA | standards-clean ports in `cases/tapenade-set06`; v314 omits only its unused `eor` data table, while v379 retains `max(n,1)` in the shape | hand JVP/VJPs, three-step central differences, adjoint identities; strict exact/reference and fresh Tapenade generated-source compilation; FortAD JVP/VJP compilation and runtime |
| `tapenade-first-aid-validity` | update the lower or upper interval bound with `temp=-t/td`, preserving inactive and zero-direction states | Tapenade `ADFirstAidKit/validityTest.f`, commit `e59864c` | MIT, INRIA | exact upstream source; no port is counted because FortAD rejects its `COMMON` state | independent lower/upper/inactive/zero-direction state transitions; legacy and strict compiler evidence; fresh Tapenade parser/JVP/VJP compile; exact FortAD refusal |
| `adbench`: Gaussian mixture model (GMM), bundle adjustment (BA), hand tracking, long short-term memory (LSTM) | as published with the suite | `microsoft/ADBench` | MIT | planned, with upstream notice | suite's own reference derivatives, plus finite differences |
| `solve-heavy` | Newton solve and a contractive fixed-point iteration | original, written from the mathematics | n/a | n/a | implicit function theorem derivative, derived by hand |
| `sparse` | Jacobians and Hessians with banded and arrowhead structure | original | n/a | n/a | dense evaluation of the same derivative |
| `scaling` | synthetic sweeps in input, output, and direction count | original | n/a | n/a | analytical, by construction |

## Fetched corpora

| Corpus | Upstream revision | Licence | Local scope | Committed here |
|---|---|---|---|---|
| Tapenade | `tapenade/tapenade` e59864cab441d4175df75383b3ff58c3dcd26df9 | MIT, INRIA | corpus defined by `docs/corpora/tapenade.toml` | source ports listed in [cases/tapenade-sources.csv](cases/tapenade-sources.csv), independent oracles and preserved probe records; the fetched checkout remains ignored |


## Tapenade ports

[cases/tapenade-sources.csv](cases/tapenade-sources.csv) maps every copied or
ported principal source to its path at the pinned Tapenade revision above.
The sources retain `Copyright (©) 1999-2021 INRIA`; the complete upstream MIT
text is in [LICENSES/Tapenade-MIT.txt](LICENSES/Tapenade-MIT.txt). The mapped
upstream files have no separate file-level licence exception.

Ports use explicit kinds, intents and names where documented by the case.
Other cases preserve exact upstream statements with an added attribution
header. Independent hand derivatives and source-validity oracles are original
benchmark code. Exact-source records under `cases/tapenade-exact/` distinguish
unsupported input, invalid upstream source, generated-code compilation and
runtime checks; a parser success is not a derivative-correctness claim.

## fortnum and fortfem operators

The original benchmark imports did not record source revisions. The source
snapshots below were checked against the retained kernels. The fortfem wrappers
were reproduced exactly from the stated snapshot, apart from their attribution
headers; fortnum scalar expressions were checked against its snapshot. These
checks identify source material, not the source revision used in every recorded
measurement. The build scripts select external checkouts; each new run must
record their revisions.

The fortfem source is
[revision 7f6cb53100b74bf45760becf4bdf0241e7ad4ac9](https://github.com/lazy-fortran/fortfem/tree/7f6cb53100b74bf45760becf4bdf0241e7ad4ac9):
`tools/fortad/catalogue.json` supplies the arguments, and
`tools/fortad/kernels/<stem>.f90` supplies each operator body.
[scripts/make_fortfem_cases.py](scripts/make_fortfem_cases.py) wraps them under
`cases/fortfem/kernels/`: inputs are unpacked from a batch, outputs are combined
with distinct integer weights, and the `_c` variants provide C interfaces.
The wrapper for `cartesian_to_toroidal` is retained but excluded from the timed
Enzyme suite; `toroidal_point_to_cartesian` is excluded by the generator because
it takes an array argument. The snapshot's MIT notice is retained in the
wrappers and [full licence](LICENSES/Fortfem-MIT.txt).

The fortnum source snapshot is
[revision a5edee19e3922ec8dc347c3bec082d01d4dc7a71](https://github.com/lazy-fortran/fortnum/tree/a5edee19e3922ec8dc347c3bec082d01d4dc7a71).
The wrappers under `cases/fortnum/kernels/` pack scalar arguments into batches
and sum the outputs, with explicit `real64` kinds and separate C interfaces.
They retain the snapshot's notice and [MIT licence](LICENSES/Fortnum-MIT.txt).

| Local operator | Source path and procedure in the fortnum snapshot |
| --- | --- |
| `det2`, `det3`, `lagrange4`, `multi_input_p2`, `multi_input_p4`, `multi_input_p8`, `multi_input_p16` | `tools/fortad/kernels/<name>.f90`; the multi-input wrappers split the expression into intermediate sums |
| `erfsum` | `tools/fortad/kernels/erf.f90`; elementwise `erf` values are summed |
| `smoke_square` | `cmake/enzyme/smoke/square.f90`, `square` |
| `scalar_root_residual` | `cmake/enzyme/hybrid/scalar_root_jvp.f90`, `residual` |
| `ode_scalar_rhs` | `cmake/enzyme/hybrid/ode_forward_sensitivity_jvp.f90`, `scalar_rhs` |
| `fixed_quadrature_integrand` | `cmake/enzyme/hybrid/fixed_quadrature_jvp.f90`, `integrand` |
| `vector_root_residual_one`, `vector_root_residual_two` | `cmake/enzyme/hybrid/vector_root_jvp.f90`, `residual_one`, `residual_two` |
| `adaptive_trace_integrand`, `singular_trace_integrand` | `cmake/enzyme/hybrid/adaptive_integrand_jvp.f90`, `integrand`, `singular_integrand` |
| `scalar_analytical_p1_jvp` | `cmake/enzyme/generated/test_scalar_wrappers.f90`, `analytical_p1_jvp` |

The independent numerical checks in `harness/bench_fortnum_suite.f90` and
`harness/bench_fortfem_suite.f90` sample input coordinates using central
differences at one step size, `h = 1e-6*max(1,abs(z_i))`, where `z_i` is the sampled input coordinate.
They do not perform a
step sweep. Forward/reverse contraction checks and cross-engine comparisons
provide further evidence. The fortnum suite also compares seven operators with
FortSym-generated derivatives; the local adapters are generated by
`scripts/make_fortsym_wrappers.py` from the external fortnum checkout's
`src/generated/fortnum_<name>_{jvp,vjp}_kernel.f90`. A finite-difference mismatch
stops either suite. In the fortfem harness, cross-engine or contraction
mismatches print diagnostics without stopping; those diagnostics must be checked
before publishing a comparison.

## Controlled Enzyme-inspired workloads

These are controlled variants of workloads discussed in Enzyme comparisons;
they are not copies of Enzyme implementation code. The immediate source is
[differentiable-fortran](https://github.com/lazy-fortran/differentiable-fortran/tree/f3649a267026d1f621f3a85329a78856d8d1000a/studies/enzyme-readme),
revision f3649a267026d1f621f3a85329a78856d8d1000a, under Apache-2.0.
Its study documents the fixed numerical contracts and their differences from
other benchmark suites.

| Local source | Source in `studies/enzyme-readme/source/kernels.f90` | Changes |
| --- | --- | --- |
| `cases/enzyme_suite/kernels_reference.f90` | complete module | original source retained, attribution header added |
| `cases/enzyme_suite/kernels/euler.f90`, `euler_c.f90` | `euler_objective` | standalone procedure; C-interoperable variant |
| `cases/enzyme_suite/kernels/rk4.f90`, `rk4_c.f90` | `rk4_objective` | standalone procedure; C-interoperable variant |
| `cases/enzyme_suite/kernels/lstm.f90`, `lstm_c.f90` | `lstm_objective` and `sigmoid` | standalone procedure, scalar helper inlined; C-interoperable variant |
| `cases/enzyme_suite/kernels/ba.f90`, `ba_c.f90` | `ba_objective` | standalone procedure; C-interoperable variant |
| `cases/enzyme_suite/kernels/bruss.f90`, `bruss_c.f90` | original scalar forced time-stepping variant | a different mathematical model from the source module's two-dimensional spatial operator |

Reused and adapted sources retain `Copyright 2026 lazy-fortran contributors`.
The full [Apache-2.0 licence](LICENSES/Differentiable-Fortran-Apache-2.0.txt)
and [applicable notice](LICENSES/Differentiable-Fortran-NOTICE.txt) accompany
them. The separate engine interface `engines/enzyme_suite.c` supplies this
harness's per-kernel interface; it is not Enzyme source.

## Measurement method

| Quantity | Method | Source |
|---|---|---|
| Complete-workload wall clock | best of N repetitions after warm-up, N and warm-up recorded | `differentiable-fortran` `docs/benchmark-method.md` |
| Peak resident memory | `/usr/bin/time -v` maximum resident set, cross-checked against `getrusage` | standard |
| Tape / checkpoint bytes | engine-reported where available, else peak resident set size (RSS) delta over the primal | per-engine, recorded |
| Build time | wall clock, split into toolchain setup, AD transformation, and compilation | original |
| Incremental rebuild | wall clock after a one-line change to the primal | original |
| Generated-code size | bytes of emitted source and of the resulting object | original |
| Vectorisation | compiler's own report, parsed; `-fopt-info-vec` and equivalents | per-compiler |
| Adjoint identity check | `⟨u, Jv⟩ = ⟨Jᵀu, v⟩` where `J` is the Jacobian, `u` an output seed and `v` an input direction; random seeds and tolerance recorded | standard |
| Finite-difference check | central differences with a step-size convergence test; the historical fortnum/fortfem suites above use one step instead | Griewank & Walther 2008 |

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
