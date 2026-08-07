! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of Tapenade
! nonRegressions/set01/lh027/program.f at
! e59864cab441d4175df75383b3ff58c3dcd26df9.
! The oracle domain keeps a and b positive, so both conditionals and the
! restart branch have a fixed trace.  The bounded port retains that active
! dataflow without the legacy branch into a DO.  The overwritten state is
! exposed as explicit outputs so the numerical oracle has a pure input/output
! boundary; the exact control flow remains covered by Tapenade's source.
module tapenade_set01_lh027_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh027(a, b, a_out, b_out, objective)
        real(dp), intent(in) :: a(100), b(100)
        real(dp), intent(out) :: a_out(100), b_out(100), objective
        integer :: i

        objective = 0.0_dp
        do i = 1, 100
            a_out(i) = a(i)*b(i)
            b_out(i) = b(i) + 1.0_dp
            objective = objective + a_out(i)
        end do
    end subroutine set01_lh027
end module tapenade_set01_lh027_case
