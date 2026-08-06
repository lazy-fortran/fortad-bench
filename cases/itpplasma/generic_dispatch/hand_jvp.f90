module generic_dispatch_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_generic_hand_jvp

contains

    pure subroutine evaluate_generic_hand_jvp(x, x_d, y, y_d)
        real(dp), intent(in) :: x, x_d
        real(dp), intent(out) :: y, y_d

        y = 2.0_dp*x + 0.5_dp + 3.0_dp*(1.25_dp*x) + 1.0_dp
        y_d = (2.0_dp + 3.0_dp*1.25_dp)*x_d
    end subroutine evaluate_generic_hand_jvp
end module generic_dispatch_hand
