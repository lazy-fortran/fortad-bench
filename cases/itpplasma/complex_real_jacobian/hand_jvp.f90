module complex_real_jacobian_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_complex_hand_jvp

contains

    pure subroutine evaluate_complex_hand_jvp(zr, zi, zr_d, zi_d, y, y_d)
        real(dp), intent(in) :: zr, zi, zr_d, zi_d
        complex(dp) :: z
        complex(dp) :: z_d
        complex(dp), intent(out) :: y, y_d

        z = cmplx(zr, zi, dp)
        z_d = cmplx(zr_d, zi_d, dp)
        y = z*z + conjg(z) + cmplx(0.0_dp, aimag(z), dp)
        y_d = 2.0_dp*z*z_d + conjg(z_d) + cmplx(0.0_dp, aimag(z_d), dp)
    end subroutine evaluate_complex_hand_jvp
end module complex_real_jacobian_hand
