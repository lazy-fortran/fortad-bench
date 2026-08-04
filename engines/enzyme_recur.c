/* Enzyme reverse-mode entry point for the recurrence kernel. */
extern int enzyme_dup;
extern int enzyme_const;

void recur(int n, const double *a, const double *b, double *s);

extern void __enzyme_autodiff(void *, ...);

void recur_vjp_enzyme(int n, const double *a, double *ab, const double *b,
                      double *bb, double *s, double *sb) {
    __enzyme_autodiff((void *)recur, enzyme_const, n, enzyme_dup, a, ab,
                      enzyme_dup, b, bb, enzyme_dup, s, sb);
}
