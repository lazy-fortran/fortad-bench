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
WRAP(fci_hendecic_bezier_edge_area)
WRAP(fci_parallel_gradient)
WRAP(fci_polygon_edge_area)
WRAP(fci_quadrilateral_cell_area)
WRAP(fci_quartic_bezier_edge_area)
WRAP(fci_quintic_lagrange_weights)
WRAP(laplace_single_layer_integrand)
WRAP(surface_triangle_geometry_3d)
