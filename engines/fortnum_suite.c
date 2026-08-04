/* Enzyme reverse-mode entry points for the fortnum operator suite.
 *
 * The same wrapper shape as the Enzyme README suite: Enzyme differentiates the
 * linked IR of the Fortran kernel and this file, so the kernels must be
 * compiled to IR by flang first.
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

WRAP(det2)
WRAP(det3)
WRAP(lagrange4)
WRAP(erfsum)
WRAP(multi_input_p2)
WRAP(multi_input_p4)
WRAP(multi_input_p8)
WRAP(multi_input_p16)
