# Tranche M: set01 lh074, lh080, and lh082

This tranche closes three consecutive pure-Fortran Tapenade rows at the pinned
`e59864c` tree. `lh080` is runnable in both modes after the local-array-element
reverse fix. `lh074` has a reproducible exact-source refusal because FortAD does
not accept its obsolete `RETURN` statement. `lh082` has a safe forward probe,
but reverse mode refuses the upstream in-place aliasing loop because a correct
adjoint needs per-iteration storage.

Every row records strict compilation attempts for the exact upstream source,
fresh Tapenade parser/tangent/reverse output, and independent hand,
finite-difference, and adjoint checks wherever the source semantics permit
them. The `lh082` port widens the upper bound for its `n=0` forward probe so
the fixed-index writes are defined. Its reverse aliasing loop remains an
intentional refusal case.
