/* Enzyme reverse-mode entry points for the seven-workload suite.
 *
 * One wrapper per workload. Enzyme differentiates the linked IR of the Fortran
 * kernel and this file, so the kernels must be compiled to IR by flang first.
 */
extern int enzyme_dup;
extern int enzyme_const;
extern void __enzyme_autodiff(void *, ...);

#define WRAP(NAME)                                                            \
    void NAME(int n, const double *z, double *y);                             \
    void NAME##_vjp_enzyme(int n, const double *z, double *zb, double *y,     \
                           double *yb) {                                      \
        __enzyme_autodiff((void *)NAME, enzyme_const, n, enzyme_dup, z, zb,   \
                          enzyme_dup, y, yb);                                 \
    }

WRAP(euler)
WRAP(rk4)
WRAP(lstm)
WRAP(bruss)
