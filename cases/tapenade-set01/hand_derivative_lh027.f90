! SPDX-License-Identifier: MIT
module tapenade_set01_lh027_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh027_hand(a, b, a_d, b_d, a_out, b_out, objective, a_out_d, &
                          b_out_d, objective_d, objective_seed, a_b, b_b)
        real(dp), intent(in) :: a(100), b(100), a_d(100), b_d(100)
        real(dp), intent(in) :: objective_seed
        real(dp), intent(out) :: a_out(100), b_out(100), objective
        real(dp), intent(out) :: a_out_d(100), b_out_d(100)
        real(dp), intent(out) :: objective_d
        real(dp), intent(out) :: a_b(100), b_b(100)
        integer :: i

        objective = 0.0_dp
        objective_d = 0.0_dp
        do i = 1, 100
            a_out(i) = a(i)*b(i)
            b_out(i) = b(i) + 1.0_dp
            a_out_d(i) = a_d(i)*b(i) + a(i)*b_d(i)
            b_out_d(i) = b_d(i)
            objective = objective + a_out(i)
            objective_d = objective_d + a_out_d(i)
            a_b(i) = objective_seed*b(i)
            b_b(i) = objective_seed*a(i)
        end do
    end subroutine lh027_hand
end module tapenade_set01_lh027_hand
