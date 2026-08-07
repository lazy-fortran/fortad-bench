module tapenade_set01_lh007_hand
    implicit none
contains

    subroutine lh007_primal(z, t, x5, x8, x10, y, u, v, x1_out, &
            x5_out, y_out, t_out, u_out, v_out)
        real, intent(in) :: z, t, x5, x8, x10, y, u, v
        real, intent(out) :: x1_out, x5_out, y_out, t_out, u_out, v_out

        x1_out = y*z + t
        x5_out = x5
        u_out = u*y + x8*z
        y_out = z + v*y
        v_out = u_out*x10
        t_out = t + x1_out*z + 3.0*v_out
    end subroutine lh007_primal

    subroutine lh007_jvp(z, zd, t, td, x5, x5d, x8, x8d, x10, x10d, &
            y, yd, u, ud, v, vd, x1_out, x1d_out, x5_out, x5d_out, &
            y_out, yd_out, t_out, td_out, u_out, ud_out, v_out, vd_out)
        real, intent(in) :: z, zd, t, td, x5, x5d, x8, x8d, x10, x10d
        real, intent(in) :: y, yd, u, ud, v, vd
        real, intent(out) :: x1_out, x1d_out, x5_out, x5d_out
        real, intent(out) :: y_out, yd_out, t_out, td_out
        real, intent(out) :: u_out, ud_out, v_out, vd_out

        x1_out = y*z + t
        x1d_out = yd*z + y*zd + td
        x5_out = x5
        x5d_out = x5d
        u_out = u*y + x8*z
        ud_out = ud*y + u*yd + x8d*z + x8*zd
        y_out = z + v*y
        yd_out = zd + vd*y + v*yd
        v_out = u_out*x10
        vd_out = ud_out*x10 + u_out*x10d
        t_out = t + x1_out*z + 3.0*v_out
        td_out = td + x1d_out*z + x1_out*zd + 3.0*vd_out
    end subroutine lh007_jvp

    subroutine lh007_vjp(z, t, x5, x8, x10, y, u, v, t_seed, &
            zb, tb, x5b, x8b, x10b, yb, ub, vb)
        real, intent(in) :: z, t, x5, x8, x10, y, u, v, t_seed
        real, intent(out) :: zb, tb, x5b, x8b, x10b, yb, ub, vb
        real :: x1_out, u_out, v_out, a_bar, u_bar

        x1_out = y*z + t
        u_out = u*y + x8*z
        v_out = u_out*x10

        tb = t_seed
        zb = x1_out*t_seed
        x5b = 0.0
        x8b = 0.0
        x10b = u_out*3.0*t_seed
        yb = 0.0
        ub = 0.0
        vb = 0.0

        a_bar = z*t_seed
        zb = zb + y*a_bar
        yb = yb + z*a_bar
        tb = tb + a_bar

        u_bar = x10*3.0*t_seed
        ub = ub + y*u_bar
        yb = yb + u*u_bar
        x8b = x8b + z*u_bar
        zb = zb + x8*u_bar
    end subroutine lh007_vjp

end module tapenade_set01_lh007_hand
