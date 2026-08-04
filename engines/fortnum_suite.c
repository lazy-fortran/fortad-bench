/* Enzyme reverse-mode entry points for the fortnum operator suite.
 *
 * The same wrapper shape as the Enzyme README suite: Enzyme differentiates the
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
    }

/* Forward mode over the same kernel, so the two directions of the comparison
 * run against the same primal rather than against two spellings of it. */
#define WRAPF(NAME)                                                           \
    void NAME##_jvp_enzyme(int n, const double *z, const double *dz,          \
                           double *y, double *dy) {                           \
        __enzyme_fwddiff((void *)NAME, enzyme_const, n, enzyme_dup, z, dz,    \
                         enzyme_dup, y, dy);                                  \
    }

WRAP(det2)
WRAP(det3)
WRAP(lagrange4)
WRAP(erfsum)
WRAP(multi_input_p2)
WRAP(multi_input_p4)
WRAP(multi_input_p8)
WRAP(multi_input_p16)
WRAP(smoke_square)
WRAP(scalar_root_residual)
WRAP(ode_scalar_rhs)
WRAP(fixed_quadrature_integrand)
WRAP(vector_root_residual_one)

WRAPF(det2)
WRAPF(det3)
WRAPF(lagrange4)
WRAPF(erfsum)
WRAPF(multi_input_p2)
WRAPF(multi_input_p4)
WRAPF(multi_input_p8)
WRAPF(multi_input_p16)
WRAPF(smoke_square)
WRAPF(scalar_root_residual)
WRAPF(ode_scalar_rhs)
WRAPF(fixed_quadrature_integrand)
WRAPF(vector_root_residual_one)
