module tapenade_set01_lh037_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh037_hand_jvp, lh037_hand_vjp

contains

    subroutine lh037_hand_jvp(a0, a0_d, b0, b0_d, c0, c0_d, a, a_d, b, b_d, c, c_d)
        real(dp), intent(in) :: a0, a0_d, b0, b0_d, c0, c0_d
        real(dp), intent(out) :: a, a_d, b, b_d, c, c_d
        real(dp) :: a1, a1_d, b1, b1_d, a2, a2_d

        a1 = a0 + b0
        a1_d = a0_d + b0_d
        b1 = b0 - c0
        b1_d = b0_d - c0_d
        c = 2.0_dp*a1*b1
        c_d = 2.0_dp*(a1_d*b1 + a1*b1_d)
        a2 = a1 + 25.5_dp
        a2_d = a1_d
        c = 2.0_dp*a2*b1
        c_d = 2.0_dp*(a2_d*b1 + a2*b1_d)
        a = 8.0_dp*a2
        a_d = 8.0_dp*a2_d
        b = b1
        b_d = b1_d
    end subroutine lh037_hand_jvp

    subroutine lh037_hand_vjp(a0, b0, c0, a_bar, b_bar, c_bar, a, b, c, a0_bar, b0_bar, c0_bar)
        real(dp), intent(in) :: a0, b0, c0, a_bar, b_bar, c_bar
        real(dp), intent(out) :: a, b, c, a0_bar, b0_bar, c0_bar
        real(dp) :: a1, a2, b1

        a1 = a0 + b0
        b1 = b0 - c0
        a2 = a1 + 25.5_dp
        a = 8.0_dp*a2
        b = b1
        c = 2.0_dp*a2*b1
        a0_bar = 8.0_dp*a_bar + 2.0_dp*b1*c_bar
        b0_bar = 8.0_dp*a_bar + b_bar + 2.0_dp*(b1 + a2)*c_bar
        c0_bar = -b_bar - 2.0_dp*a2*c_bar
    end subroutine lh037_hand_vjp

end module tapenade_set01_lh037_hand
