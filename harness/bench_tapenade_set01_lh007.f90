program bench_tapenade_set01_lh007
    use lh007_forward, only: lh007_jvp_generated => lh007_jvp
    use lh007_reverse, only: lh007_vjp_generated => lh007_vjp
    use tapenade_set01_lh007_hand, only: lh007_jvp_hand => lh007_jvp, &
        lh007_vjp_hand => lh007_vjp, lh007_primal
    implicit none

    real :: z, zd, t, td, x5, x5d, x8, x8d, x10, x10d
    real :: y, yd, u, ud, v, vd
    real :: x1, x1d, x5o, x5od, yo, yod, to, tod, uo, uod, vo, vod
    real :: x1h, x1dh, x5oh, x5odh, yh, ydh, th, tdh, uh, udh, vh, vdh
    real :: t_seed, zb, tb, x5b, x8b, x10b, yb, ub, vb
    real :: zbh, tbh, x5bh, x8bh, x10bh, ybh, ubh, vbh
    real :: x1p, x5op, yop, top, uop, vop
    real :: x1m, x5om, yom, tom, uom, vom
    real :: h, fd, lhs, rhs
    logical :: ok
    integer :: step

    z = 0.73
    zd = -0.21
    t = -0.46
    td = 0.37
    x5 = 0.19
    x5d = -0.18
    x8 = -0.62
    x8d = 0.29
    x10 = 1.14
    x10d = -0.27
    y = 1.31
    yd = -0.16
    u = -0.57
    ud = 0.33
    v = 0.84
    vd = -0.12
    t_seed = -0.71
    ok = .true.

    call lh007_jvp_generated(z, zd, t, td, x5, x5d, x8, x8d, x10, x10d, &
        y, yd, u, ud, v, vd, x1, x1d, x5o, x5od, yo, yod, to, tod, uo, &
        uod, vo, vod)
    call lh007_jvp_hand(z, zd, t, td, x5, x5d, x8, x8d, x10, x10d, y, yd, &
        u, ud, v, vd, x1h, x1dh, x5oh, x5odh, yh, ydh, th, tdh, uh, udh, &
        vh, vdh)
    call check_close("JVP x1", x1, x1h, ok)
    call check_close("JVP x1 tangent", x1d, x1dh, ok)
    call check_close("JVP x5", x5o, x5oh, ok)
    call check_close("JVP x5 tangent", x5od, x5odh, ok)
    call check_close("JVP y", yo, yh, ok)
    call check_close("JVP y tangent", yod, ydh, ok)
    call check_close("JVP t", to, th, ok)
    call check_close("JVP t tangent", tod, tdh, ok)
    call check_close("JVP u", uo, uh, ok)
    call check_close("JVP u tangent", uod, udh, ok)
    call check_close("JVP v", vo, vh, ok)
    call check_close("JVP v tangent", vod, vdh, ok)

    call lh007_vjp_generated(z, t, x5, x8, x10, y, u, v, x1, x5o, yo, to, &
        uo, vo, t_seed, zb, tb, x5b, x8b, x10b, yb, ub, vb)
    call lh007_vjp_hand(z, t, x5, x8, x10, y, u, v, t_seed, zbh, tbh, &
        x5bh, x8bh, x10bh, ybh, ubh, vbh)
    call check_close("VJP z", zb, zbh, ok)
    call check_close("VJP t", tb, tbh, ok)
    call check_close("VJP x5", x5b, x5bh, ok)
    call check_close("VJP x8", x8b, x8bh, ok)
    call check_close("VJP x10", x10b, x10bh, ok)
    call check_close("VJP y", yb, ybh, ok)
    call check_close("VJP u", ub, ubh, ok)
    call check_close("VJP v", vb, vbh, ok)

    lhs = t_seed*tod
    rhs = zb*zd + tb*td + x5b*x5d + x8b*x8d + x10b*x10d + yb*yd + &
        ub*ud + vb*vd
    call check_close("adjoint identity", lhs, rhs, ok)

    do step = 2, 4
        h = 10.0**(-step)
        call lh007_primal(z + h*zd, t + h*td, x5 + h*x5d, x8 + h*x8d, &
            x10 + h*x10d, y + h*yd, u + h*ud, v + h*vd, x1p, x5op, &
            yop, top, uop, vop)
        call lh007_primal(z - h*zd, t - h*td, x5 - h*x5d, x8 - h*x8d, &
            x10 - h*x10d, y - h*yd, u - h*ud, v - h*vd, x1m, x5om, &
            yom, tom, uom, vom)
        fd = (top - tom)/(2.0*h)
        call check_close_tol("central difference", fd, tod, 3.0e-3, ok)
    end do

    if (.not. ok) error stop "Tapenade set01 lh007 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual, expected
        logical, intent(inout) :: ok

        if (abs(actual - expected) > 5.0e-5*max(1.0, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_close_tol(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual, expected, tolerance
        logical, intent(inout) :: ok

        if (abs(actual - expected) > tolerance*max(1.0, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close_tol

end program bench_tapenade_set01_lh007
