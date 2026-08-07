module tapenade_set01_lh088_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: lh088_hand_jvp, lh088_hand_vjp

contains

    subroutine lh088_hand_jvp(a, a_d, b, b_d, c, c_d, d, d_d, total, total_d)
        real(dp), intent(in) :: a, a_d, b, b_d, c, c_d, d, d_d
        real(dp), intent(out) :: total, total_d
        real(dp) :: a_out, a_out_d, b_out, b_out_d, c_out, c_out_d

        a_out = sqrt(b)
        a_out_d = b_d/(2.0_dp*sqrt(b))
        b_out = log(c)
        b_out_d = c_d/c
        c_out = c**d
        c_out_d = c**d*(d_d*log(c) + d*c_d/c)
        total = a_out + b_out + c_out
        total_d = a_out_d + b_out_d + c_out_d
    end subroutine lh088_hand_jvp

    subroutine lh088_hand_vjp(a, b, c, d, total_b, total, a_b, b_b, c_b, d_b)
        real(dp), intent(in) :: a, b, c, d, total_b
        real(dp), intent(out) :: total, a_b, b_b, c_b, d_b

        total = sqrt(b) + log(c) + c**d
        a_b = 0.0_dp
        b_b = total_b/(2.0_dp*sqrt(b))
        c_b = total_b*(1.0_dp/c + d*c**(d - 1.0_dp))
        d_b = total_b*c**d*log(c)
    end subroutine lh088_hand_vjp

end module tapenade_set01_lh088_hand
