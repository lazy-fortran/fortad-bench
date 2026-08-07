module tapenade_set01_lh049_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh049_hand_jvp, lh049_hand_vjp

contains

    subroutine lh049_hand_jvp(x, x_d, y, y_d, z, z_d)
        real(dp), intent(in) :: x, x_d
        real(dp), intent(inout) :: y, y_d
        real(dp), intent(out) :: z, z_d
        real(dp) :: u, u_d

        u = x*y
        u_d = x_d*y + x*y_d
        z = 3.0_dp*u**2 + x
        z_d = 6.0_dp*u*u_d + x_d
        y = 2.0_dp*x
        y_d = 2.0_dp*x_d
    end subroutine lh049_hand_jvp

    subroutine lh049_hand_vjp(x, y, z, z_b, x_b, y_b)
        real(dp), intent(in) :: x, y, z_b
        real(dp), intent(out) :: z, x_b, y_b
        real(dp) :: u

        u = x*y
        z = 3.0_dp*u**2 + x
        x_b = z_b*(6.0_dp*x*y**2 + 1.0_dp)
        y_b = z_b*(6.0_dp*x**2*y)
    end subroutine lh049_hand_vjp

end module tapenade_set01_lh049_hand
