/* Enzyme entry points for the fortfem operator suite.
 *
 * The same wrapper shape as the other two suites: Enzyme differentiates the
 * linked IR of the Fortran kernel and this file, so the kernels must be
 * compiled to IR by flang first.
 */
extern int enzyme_dup;
extern int enzyme_const;
extern void __enzyme_autodiff(void *, ...);
extern void __enzyme_fwddiff(void *, ...);

#define WRAP(NAME)                                                            \
    void NAME(int n, const double *z, double *y);                             \
    void NAME##_vjp_enzyme(int n, const double *z, double *zb, double *y,     \
                           double *yb) {                                      \
        __enzyme_autodiff((void *)NAME, enzyme_const, n, enzyme_dup, z, zb,   \
                          enzyme_dup, y, yb);                                 \
    }                                                                         \
    void NAME##_jvp_enzyme(int n, const double *z, const double *dz,          \
                           double *y, double *dy) {                           \
        __enzyme_fwddiff((void *)NAME, enzyme_const, n, enzyme_dup, z, dz,    \
                         enzyme_dup, y, dy);                                  \
    }

WRAP(cgl_pressure_tensor)
WRAP(block_graph_product)
WRAP(cgl_pressure_divergence)
WRAP(fci_cubic_bezier_edge_area)
WRAP(fci_cubic_lagrange_weights)
WRAP(fci_curved_quadrilateral_cell_area)
WRAP(fci_decic_bezier_edge_area)
WRAP(fci_nonic_bezier_edge_area)
WRAP(fci_octic_bezier_edge_area)
WRAP(fci_parallel_diffusion)
WRAP(fci_parallel_flux_power)
WRAP(fci_perpendicular_power)
WRAP(fci_quadratic_bezier_edge_area)
WRAP(fci_quadratic_lagrange_weights)
WRAP(fci_quartic_lagrange_weights)
WRAP(fci_quintic_bezier_edge_area)
WRAP(fci_septic_bezier_edge_area)
WRAP(fci_sextic_bezier_edge_area)
WRAP(fci_sextic_lagrange_weights)
WRAP(fci_staggered_flux_box_volume)
WRAP(field_aligned_flux)
WRAP(field_aligned_hall)
WRAP(force_balance_product)
WRAP(helmholtz_single_layer_integrand)
WRAP(helmholtz_single_layer_smooth_integrand)
WRAP(laplace_singular_edge_potential)
WRAP(regularized_surface_current)
WRAP(sphere_curved_panel)
WRAP(surface_integral_contribution)
WRAP(surface_shape_objective_contribution)
WRAP(tensor_power_split)
WRAP(toroidal_poisson_products)
WRAP(toroidal_vector_to_cartesian)
WRAP(torus_curved_panel)
WRAP(fci_hendecic_bezier_edge_area)
WRAP(fci_parallel_gradient)
WRAP(fci_polygon_edge_area)
WRAP(fci_quadrilateral_cell_area)
WRAP(fci_quartic_bezier_edge_area)
WRAP(fci_quintic_lagrange_weights)
WRAP(laplace_single_layer_integrand)
WRAP(surface_triangle_geometry_3d)
