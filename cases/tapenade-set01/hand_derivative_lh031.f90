! SPDX-License-Identifier: MIT
! Independent closed-form JVP/VJP oracle for the bounded lh031 port.
module tapenade_set01_lh031_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh031_jvp(x, y, z, xd, yd, zd, x_out, y_out, z_out, &
                         xd_out, yd_out, zd_out)
        real(dp), intent(in) :: x, y, z, xd, yd, zd
        real(dp), intent(out) :: x_out, y_out, z_out
        real(dp), intent(out) :: xd_out, yd_out, zd_out
        real(dp) :: xa, ya, za, xad, yad, zad

        xa = x + sin(x) - y
        xad = (1.0_dp + cos(x))*xd - yd
        ya = y*xa
        yad = yd*xa + y*xad
        za = z + xa*ya
        zad = zd + xad*ya + xa*yad
        x_out = xa
        y_out = ya
        z_out = za
        xd_out = xad
        yd_out = yad
        zd_out = zad
    end subroutine lh031_jvp

    subroutine lh031_vjp(x, y, z, x_out, y_out, z_out, x_seed, y_seed, z_seed, &
                         x_bar, y_bar, z_bar)
        real(dp), intent(in) :: x, y, z, x_out, y_out, z_out
        real(dp), intent(in) :: x_seed, y_seed, z_seed
        real(dp), intent(out) :: x_bar, y_bar, z_bar
        real(dp) :: a_bar

        a_bar = x_seed + z_seed*y_out + z_seed*x_out*y + y_seed*y
        x_bar = a_bar*(1.0_dp + cos(x))
        y_bar = z_seed*x_out*x_out + y_seed*x_out - a_bar
        z_bar = z_seed
    end subroutine lh031_vjp
end module tapenade_set01_lh031_hand
