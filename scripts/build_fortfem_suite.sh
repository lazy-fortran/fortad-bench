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

out=build/fortfem_suite
rm -rf "$out"
mkdir -p "$out" results

WORKLOADS="fci_polygon_edge_area fci_quadrilateral_cell_area fci_quartic_bezier_edge_area fci_hendecic_bezier_edge_area fci_parallel_gradient fci_quintic_lagrange_weights cgl_pressure_tensor laplace_single_layer_integrand surface_triangle_geometry_3d"

echo "== Enzyme"
for k in $WORKLOADS; do
    "$flang" -O3 -fPIC -S -emit-llvm "cases/fortfem/kernels/${k}_c.f90" \
        -o "$out/$k.ll" -module-dir "$out"
done
"$clang" -O3 -fPIC -S -emit-llvm engines/fortfem_suite.c -o "$out/wrapper.ll"
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
        -o "$out/${k}_vjp.f90" "cases/fortfem/kernels/$k.f90"
    "$flang" -O3 -c "$out/${k}_vjp.f90" -o "$out/${k}_vjp.o" -module-dir "$out"
    # Gradient-only: the same contract Tapenade's reverse routine offers.
    "$fortad_bin" --mode reverse --indep z --no-primal --name "${k}_grad" \
        -o "$out/${k}_grad.f90" "cases/fortfem/kernels/$k.f90"
    "$fortad_bin" --indep z --name "${k}_jvp" \
        -o "$out/${k}_jvp.f90" "cases/fortfem/kernels/$k.f90"
    "$flang" -O3 -c "$out/${k}_grad.f90" -o "$out/${k}_grad.o" -module-dir "$out"
    "$flang" -O3 -c "$out/${k}_jvp.f90" -o "$out/${k}_jvp.o" -module-dir "$out"
done

echo "== driver"
"$flang" -O3 -o "$out/bench" harness/bench_fortfem_suite.f90 \
    $(for k in $WORKLOADS; do echo "$out/${k}_vjp.o" "$out/${k}_grad.o" \
        "$out/${k}_jvp.o"; done) \
    "$out/enzyme.o" \

echo "built $out/bench"
