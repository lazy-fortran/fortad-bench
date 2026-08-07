! Independent hand JVP/VJP oracle for the bd01 port.
module tapenade_set01_bd01_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: bd01_hand_jvp, bd01_hand_vjp

contains

    subroutine bd01_hand_jvp(x, xd, y, yd, z, zd, w, wd, xf, xfd, yf, yfd, zf, zfd)
        real(dp), intent(in) :: x, xd, y, yd, z, zd
        real(dp), intent(out) :: w, wd, xf, xfd, yf, yfd, zf, zfd
        real(dp) :: a, ad

        a = x + y
        ad = xd + yd
        w = x*y*z*a
        wd = z*a*(y*xd + x*yd) + x*y*(a*zd + z*ad)
        xf = w*w
        xfd = 2.0_dp*w*wd
        yf = xf + w*z
        yfd = xfd + wd*z + w*zd
        zf = z
        zfd = zd
    end subroutine bd01_hand_jvp

    subroutine bd01_hand_vjp(x, y, z, wb, w, xb, yb, zb)
        real(dp), intent(in) :: x, y, z, wb
        real(dp), intent(out) :: w, xb, yb, zb
        real(dp) :: a, tempb

        a = x + y
        w = x*y*z*a
        tempb = z*a*wb
        xb = y*tempb + z*x*y*wb
        yb = x*tempb + z*x*y*wb
        zb = a*x*y*wb
    end subroutine bd01_hand_vjp

end module tapenade_set01_bd01_hand
