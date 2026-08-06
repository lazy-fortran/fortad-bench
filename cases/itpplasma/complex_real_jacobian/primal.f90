module complex_real_jacobian_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_complex

contains

    pure function evaluate_complex(zr, zi) result(y)
        real(dp), intent(in) :: zr, zi
        complex(dp) :: z
        complex(dp) :: y

        z = cmplx(zr, zi, dp)
        y = z*z + conjg(z) + cmplx(0.0_dp, aimag(z), dp)
    end function evaluate_complex
end module complex_real_jacobian_kernel
