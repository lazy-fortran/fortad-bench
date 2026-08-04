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

# cartesian_to_toroidal is left out: Enzyme has no derivative rule for
# atan2 and refuses the kernel, so there is nothing to compare against.
# fortad differentiates it; the fortfem equivalence tests cover that.
WORKLOADS="block_graph_product cgl_pressure_divergence cgl_pressure_tensor fci_cubic_bezier_edge_area fci_cubic_lagrange_weights fci_curved_quadrilateral_cell_area fci_decic_bezier_edge_area fci_hendecic_bezier_edge_area fci_nonic_bezier_edge_area fci_octic_bezier_edge_area fci_parallel_diffusion fci_parallel_flux_power fci_parallel_gradient fci_perpendicular_power fci_polygon_edge_area fci_quadratic_bezier_edge_area fci_quadratic_lagrange_weights fci_quadrilateral_cell_area fci_quartic_bezier_edge_area fci_quartic_lagrange_weights fci_quintic_bezier_edge_area fci_quintic_lagrange_weights fci_septic_bezier_edge_area fci_sextic_bezier_edge_area fci_sextic_lagrange_weights fci_staggered_flux_box_volume field_aligned_flux field_aligned_hall force_balance_product helmholtz_single_layer_integrand helmholtz_single_layer_smooth_integrand laplace_single_layer_integrand laplace_singular_edge_potential regularized_surface_current sphere_curved_panel surface_integral_contribution surface_shape_objective_contribution surface_triangle_geometry_3d tensor_power_split toroidal_poisson_products toroidal_vector_to_cartesian torus_curved_panel"

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
    # The undifferentiated kernel: the reference row, and the primal the
    # harness calls directly for its finite-difference check. Enzyme has its
    # own copy through the C-bound variant, under a different symbol.
    "$flang" -O3 -c "cases/fortfem/kernels/$k.f90" \
        -o "$out/${k}_primal.o" -module-dir "$out"
done

echo "== driver"
"$flang" -O3 -o "$out/bench" harness/bench_fortfem_suite.f90 \
    $(for k in $WORKLOADS; do echo "$out/${k}_vjp.o" "$out/${k}_grad.o" \
        "$out/${k}_jvp.o" "$out/${k}_primal.o"; done) \
    "$out/enzyme.o" \

echo "built $out/bench"
