! SPDX-License-Identifier: MIT
!
! Bounded, standard-conforming interpretation of Tapenade
! nonRegressions/set01/lh009/program.f at e59864c.  The upstream file has
! conflicting REAL/CHARACTER declarations for A, so this port is used only
! for an independent numerical oracle; it is not a FortAD support claim.
subroutine set01_lh009(a_in, b_in, s, a_out, b_out)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a_in(0:1000), b_in(0:1000)
    integer, intent(in) :: s
    real(dp), intent(out) :: a_out(0:1000), b_out(0:1000)
    integer :: i

    a_out = a_in
    b_out = b_in
    do i = s, 1000 - s
        b_out(i) = a_out(i - s)*a_out(i + s)
        a_out(i) = 2.0_dp*a_out(i) + 0.5_dp
    end do
end subroutine set01_lh009
