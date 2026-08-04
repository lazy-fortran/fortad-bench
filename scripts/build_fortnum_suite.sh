#!/usr/bin/env bash
# Build every fortnum operator for both engines.
#
# Enzyme goes through the documented flang -> LLVM IR -> opt -passes=enzyme
# route. fortad reads the same numerical kernel as plain Fortran. Both are then
# compiled by the same flang, so the comparison is of the derivative code and
# not of two different compilers.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

flang=${FLANG:-flang}
clang=${CLANG:-clang}
opt=${OPT:-opt}
llvm_link=${LLVM_LINK:-llvm-link}
plugin=${ENZYME_PLUGIN:-$HOME/code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so}
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
fortad_bin=$(find "$fortad_repo/build" -name fortad -type f -perm -u+x | head -1)

out=build/fortnum_suite
rm -rf "$out"
mkdir -p "$out" results

WORKLOADS="det2 det3 lagrange4 erfsum multi_input_p2 multi_input_p4 multi_input_p8 multi_input_p16 smoke_square scalar_root_residual ode_scalar_rhs fixed_quadrature_integrand vector_root_residual_one vector_root_residual_two adaptive_trace_integrand singular_trace_integrand scalar_analytical_p1_jvp"

echo "== Enzyme"
for k in $WORKLOADS; do
    "$flang" -O3 -fPIC -S -emit-llvm "cases/fortnum/kernels/${k}_c.f90" \
        -o "$out/$k.ll" -module-dir "$out"
done
"$clang" -O3 -fPIC -S -emit-llvm engines/fortnum_suite.c -o "$out/wrapper.ll"
# shellcheck disable=SC2086
"$llvm_link" -S $(for k in $WORKLOADS; do echo "$out/$k.ll"; done) \
    "$out/wrapper.ll" -o "$out/linked.ll"
"$opt" -load-pass-plugin="$plugin" -passes=enzyme "$out/linked.ll" -S \
    -o "$out/enzyme.ll"
"$opt" -O3 "$out/enzyme.ll" -S -o "$out/enzyme_opt.ll"
"$clang" -O3 -fPIC -c "$out/enzyme_opt.ll" -o "$out/enzyme.o"

echo "== fortad"
for k in $WORKLOADS; do
    "$fortad_bin" --mode reverse --indep z --name "${k}_vjp" \
        -o "$out/${k}_vjp.f90" "cases/fortnum/kernels/$k.f90"
    "$flang" -O3 -c "$out/${k}_vjp.f90" -o "$out/${k}_vjp.o" -module-dir "$out"
    # Gradient-only: the same contract Tapenade's reverse routine offers.
    "$fortad_bin" --mode reverse --indep z --no-primal --name "${k}_grad" \
        -o "$out/${k}_grad.f90" "cases/fortnum/kernels/$k.f90"
    "$fortad_bin" --indep z --name "${k}_jvp" \
        -o "$out/${k}_jvp.f90" "cases/fortnum/kernels/$k.f90"
    "$flang" -O3 -c "$out/${k}_grad.f90" -o "$out/${k}_grad.o" -module-dir "$out"
    "$flang" -O3 -c "$out/${k}_jvp.f90" -o "$out/${k}_jvp.o" -module-dir "$out"
    # The undifferentiated kernel, as the reference row and as the primal the
    # harness calls directly. Enzyme gets its own copy through the C-bound
    # variant, which carries a different symbol, so there is no clash.
    "$flang" -O3 -c "cases/fortnum/kernels/$k.f90" \
        -o "$out/${k}_primal.o" -module-dir "$out"
done

echo "== fortsym"
# fortsym's own kernels, compiled from fortnum, with a batch loop around each.
# The loop is the same one the other two engines have, so what is timed is the
# kernel rather than three different callers.
fortnum_repo=${FORTNUM_REPO:-"$root/../fortnum"}
python3 scripts/make_fortsym_wrappers.py > /dev/null
FORTSYM_OPS="det2 det3 lagrange4 multi_input_p2 multi_input_p4 multi_input_p8 multi_input_p16"
for k in $FORTSYM_OPS; do
    for product in jvp vjp; do
        "$flang" -O3 -c "$fortnum_repo/src/generated/fortnum_${k}_${product}_kernel.f90" \
            -o "$out/fortsym_${k}_${product}.o" -module-dir "$out"
    done
done
for k in $FORTSYM_OPS; do
    "$flang" -O3 -c "cases/fortnum/fortsym/${k}_fortsym.f90" \
        -o "$out/${k}_fortsym.o" -module-dir "$out"
done

echo "== driver"
"$flang" -O3 -o "$out/bench" harness/bench_fortnum_suite.f90 \
    $(for k in $WORKLOADS; do echo "$out/${k}_vjp.o" "$out/${k}_grad.o" \
        "$out/${k}_jvp.o" "$out/${k}_primal.o"; done) \
    $(for k in det2 det3 lagrange4 multi_input_p2 multi_input_p4 multi_input_p8 \
        multi_input_p16; do echo "$out/fortsym_${k}_jvp.o" \
        "$out/fortsym_${k}_vjp.o" "$out/${k}_fortsym.o"; done) \
    "$out/enzyme.o" -module-dir "$out"

echo "built $out/bench"
