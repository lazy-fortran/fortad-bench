! SPDX-License-Identifier: MIT
module tapenade_set01_lh020_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh020_hand(x, y, n, dx, dy, seed, x1_out, branch, jvp, x_b, y_b)
        real(dp), intent(in) :: x(:), y(:), dx(:), dy(:), seed
        integer, intent(in) :: n
        real(dp), intent(out) :: x1_out, jvp, x_b(:), y_b(:)
        integer, intent(out) :: branch

        if (n < 1) error stop "lh020 hand oracle requires n >= 1"

        x1_out = x(1)*y(1)
        branch = 1
        jvp = y(1)*dx(1) + x(1)*dy(1)
        x_b = 0.0_dp
        y_b = 0.0_dp
        x_b(1) = seed*y(1)
        y_b(1) = seed*x(1)
    end subroutine lh020_hand
end module tapenade_set01_lh020_hand
