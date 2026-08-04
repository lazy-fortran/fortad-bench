/* Enzyme forward-mode entry point for the dot_sin kernel.
 *
 * Enzyme differentiates LLVM IR, so the Fortran kernel is compiled to IR by
 * flang, this wrapper to IR by clang, the two are linked, and the enzyme pass
 * runs over the result. The __enzyme_* names are part of Enzyme's ABI and are
 * matched by symbol name, so they cannot be renamed or made static.
 */
extern int enzyme_dup;
extern int enzyme_const;

void dot_sin(int n, const double *a, const double *b, double *s);

extern void __enzyme_fwddiff(void *, ...);

/* One tangent direction: the shadow arrays carry the seed in and the
 * directional derivative out. */
void dot_sin_jvp_enzyme(int n, const double *a, const double *ad,
                        const double *b, const double *bd, double *s,
                        double *sd) {
    __enzyme_fwddiff((void *)dot_sin, enzyme_const, n, enzyme_dup, a, ad,
                     enzyme_dup, b, bd, enzyme_dup, s, sd);
}
