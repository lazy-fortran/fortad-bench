! SPDX-License-Identifier: MIT
! Independent closed-form JVP/VJP oracle for the bounded lh045 port.
module tapenade_set01_lh045_hand
    implicit none
contains
    subroutine lh045_jvp(x, y, w4, v2, xd, yd, w4d, v2d, x_out, z, w4_out, &
                         xod, zd, w4od)
        real(kind=8), intent(in) :: x, y, w4, v2, xd, yd, w4d, v2d
        real(kind=8), intent(out) :: x_out, z, w4_out, xod, zd, w4od
        real(kind=8) :: t, v1, v1d, p

        v1 = x*v2 - 105.0d0
        v1d = xd*v2 + x*v2d
        t = y - 10.0d0
        x_out = x
        xod = xd
        if (x > y) then
            x_out = t
            xod = yd
        end if
        p = v1 + 6.0d0
        z = 2.0d0*p + w4
        zd = 2.0d0*v1d + w4d
        w4_out = v1*v2
        w4od = v1d*v2 + v1*v2d
    end subroutine lh045_jvp

    subroutine lh045_vjp(x, y, w4, v2, x_out, x_seed, z_seed, w4_seed, &
                         xb, yb, w4b, v2b)
        real(kind=8), intent(in) :: x, y, w4, v2, x_out
        real(kind=8), intent(in) :: x_seed, z_seed, w4_seed
        real(kind=8), intent(out) :: xb, yb, w4b, v2b
        real(kind=8) :: branch_x

        branch_x = 1.0d0
        if (x > y) branch_x = 0.0d0
        xb = branch_x*x_seed + 2.0d0*v2*z_seed + &
             v2*v2*w4_seed
        yb = (1.0d0 - branch_x)*x_seed
        w4b = z_seed
        v2b = 2.0d0*x*z_seed + (2.0d0*x*v2 - 105.0d0)*w4_seed
    end subroutine lh045_vjp
end module tapenade_set01_lh045_hand
