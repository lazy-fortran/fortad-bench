! Bounded standard-conforming port of the returned top observable.
!
! The exact corpus has an invalid procedure dummy named COMPUTE that is also
! imported from M1_I.  This port keeps the executable computation visible in
! that chain: COMPUTE forms 2*r and returns the product of its two components, while FTEST and TOP
! forward that scalar.  The source's global accumulator and caller-visible s
! are not part of TOP's returned observable and are deliberately outside this
! port's contract.  The returned function value is exposed as an output
! argument so the bounded port has a form FortAD can differentiate.
subroutine set01_v504(r, s, top)
    implicit none
    real, intent(in) :: r(2), s(2)
    real, intent(out) :: top
    top = (2.0 * r(1)) * (2.0 * r(2))
end subroutine set01_v504
