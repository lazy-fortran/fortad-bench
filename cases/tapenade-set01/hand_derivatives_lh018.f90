! SPDX-License-Identifier: MIT
module tapenade_set01_lh018_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh018_hand(b, c, direction_b, direction_c, seed, a_out, jvp, &
                          vjp_b, vjp_c)
        real(dp), intent(in) :: b, c(20), direction_b, direction_c(20), seed
        real(dp), intent(out) :: a_out, jvp, vjp_b, vjp_c(20)
        real(dp) :: gradient_b, gradient_c10

        a_out = 343.0_dp*b*c(10)
        gradient_b = 343.0_dp*c(10)
        gradient_c10 = 343.0_dp*b
        jvp = gradient_b*direction_b + gradient_c10*direction_c(10)
        vjp_b = seed*gradient_b
        vjp_c = 0.0_dp
        vjp_c(10) = seed*gradient_c10
    end subroutine lh018_hand
end module tapenade_set01_lh018_hand
