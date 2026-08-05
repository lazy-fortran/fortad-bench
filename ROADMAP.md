# fortad-bench roadmap

This repository is where fortad's performance claim is demonstrated or
refuted. It holds the workloads, the engine adapters, the harness, and the
committed results. `README.md` reports the current numbers; this file tracks
what is missing from them.

## Status, 2026-08-05

Coverage stands at 59 operators: 17 in the fortnum suite and 42 in the
fortfem suite, plus Enzyme's own suite. Every operator that both Enzyme and
fortad can differentiate has numbers recorded. Nearly all measurements sit
within the 30% band agreed for the port; the exceptions are named below.

`cases/fortfem/kernels/` holds 43 kernel sources against the harness's
`NW = 42`. Reconcile the two: either the extra case is intentionally not
benchmarked, in which case say so, or a measurement is missing.

## Outstanding

### Re-measure the vector-Newton routines

Three of fortnum's vector-Newton routines were absent from the corpus
because fortad could not differentiate them: `hoist_subexpressions` did not
terminate on a body with several inlined callees. That defect is fixed. The
routines have not been added or measured since, and they are the last of
Enzyme's fortnum corpus that fortad did not cover.

### Two caveats in the committed results

Both are recorded in `README.md` and neither is resolved:

- `rk4` reverse at 0.11x is the widest margin in the corpus and the least
  representative. The kernel is a linear ODE, so its stages collapse to an
  affine recurrence and fortad's analysis reduces the adjoint to two fused
  multiply-adds per step with no tape. The transformation is general rather
  than fitted to this kernel, but the margin should not be quoted as
  typical, and Tapenade is the engine that would confirm it.
- `adaptive_trace_integrand` tangent at 1.69x is the one fortnum
  measurement outside 30%, and the derivative is not the reason: fortad
  emits the minimal form and compiles to 68 instructions against Enzyme's
  119, and is still slower. Fewer instructions, more time. This is a
  code-generation question for the compiler, not a fortad rule, and it is
  unresolved.
- fortfem's curved quadrilateral cell area tangent at 1.63x is the widest
  gap in that suite, caused by slice packing paying twice on a wide
  operator. Diagnosed in the fortad roadmap; unfixed.

### Tapenade

Tapenade is the third engine of interest and the only other one that does
the affine-recurrence collapse through its to-be-recorded analysis, which
makes it the honest comparison for the `rk4` reverse result. It is not yet
wired into the harness.

### Build-time measurement

The stated goal is to be faster than every engine at build time as well as
runtime. Runtime is measured throughout; build time is not measured at all.

## Harness notes for anyone extending this

- `scripts/build_fortnum_suite.sh` and `scripts/build_fortfem_suite.sh`
  compile and link each kernel's own primal (`${k}_primal.o`). Enzyme gets
  its own copy through the C-bound variant, which carries a different
  symbol, so there is no clash.
- Both engines are compiled by the same flang, deliberately: the comparison
  is of the derivative code, not of two compilers.
- fortsym kernels are wrapped with the same batch loop as the other engines
  so what is timed is the kernel rather than three different callers.
- `scripts/make_fortfem_cases.py` generates the fortfem cases from fortfem's
  extracted primals; its `CHOSEN` list currently covers all 44 candidates.
- A single evaluation of most of these kernels is far below timer
  resolution. Everything is batched, which is also how fortfem and fortnum
  actually call them: once per cell or per quadrature point.
