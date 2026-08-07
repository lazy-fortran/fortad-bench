! SPDX-License-Identifier: MIT
! Adapted from Tapenade nonRegressions/set01/lh010/program.f at e59864c.
module tapenade_set01_lh010_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh010(x, total)
        real(dp), intent(in) :: x(100)
        real(dp), intent(out) :: total
        real(dp) :: product_term
        integer :: i

        total = 0.0_dp
        product_term = 10.0_dp
        do i = 1, 100
            product_term = product_term*x(i)
            total = total + x(i)
        end do
        total = total + product_term
    end subroutine set01_lh010
end module tapenade_set01_lh010_case
