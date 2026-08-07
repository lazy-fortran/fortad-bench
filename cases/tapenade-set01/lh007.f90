! Bounded, standard-conforming oracle port of
! Tapenade nonRegressions/set01/lh007/program.f.
!
! The exact regression passes x(5) to the explicit-shape dummy Y2(0:6).
! Its two reads therefore observe x(8) and x(10) on the usual contiguous
! storage model.  The port makes those observations explicit, and exposes
! the formerly local U/V values as initialized inputs so the undefined local
! reads in the exact source do not enter the numerical oracle.
subroutine set01_lh007(z, t, x5, x8, x10, y, u, v, x1_out, x5_out, &
        y_out, t_out, u_out, v_out)
    implicit none
    real, intent(in) :: z, t, x5, x8, x10, y, u, v
    real, intent(out) :: x1_out, x5_out, y_out, t_out, u_out, v_out

    x1_out = y*z + t
    x5_out = x5
    u_out = u*y + x8*z
    y_out = z + v*y
    v_out = u_out*x10
    t_out = t + x1_out*z + 3.0*v_out
end subroutine set01_lh007
