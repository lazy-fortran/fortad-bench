! Independent behavioral harness: hand JVP/VJP, finite differences, and
! the adjoint identity on both sides of the branch boundary.
program test_lh045
    use tapenade_set01_lh045_hand
    use lh045_jvp_mod, only: fortad_lh045_jvp => lh045_jvp
    implicit none
    real(kind=8) :: x, y, w4, v2, xd, yd, w4d, v2d
    real(kind=8) :: xo, z, wo, xod, zd, wod
    real(kind=8) :: gxo, gz, gwo, gxod, gzd, gwod
    real(kind=8) :: hx, hy, hw, hv, xp, yp, wp, vp, xm, ym, wm, vm
    real(kind=8) :: xop, zp, wop, xom, zm, wom, xfd, zfd, wfd
    real(kind=8) :: xs, zs, ws, xb, yb, wb, vb, lhs, rhs, scale
    integer :: i

    do i = 1, 2
        if (i == 1) then
            x = 2.4d0
            y = 1.1d0
        else
            x = 0.7d0
            y = 1.1d0
        end if
        w4 = -0.35d0
        v2 = 1.25d0
        xd = 0.31d0
        yd = -0.22d0
        w4d = 0.17d0
        v2d = -0.13d0
        call set01_lh045(x, y, w4, v2, xo, z, wo)
        call lh045_jvp(x, y, w4, v2, xd, yd, w4d, v2d, xo, z, wo, &
                       xod, zd, wod)
        call fortad_lh045_jvp(x, xd, y, yd, w4, w4d, v2, v2d, gxo, gxod, gz, gzd, &
                              gwo, gwod)
        if (max(abs(gxo-xo), abs(gz-z), abs(gwo-wo), abs(gxod-xod), &
                abs(gzd-zd), abs(gwod-wod)) > 2.0d-13) error stop 13

        hx = 1.0d-6
        hy = 1.0d-6
        hw = 1.0d-6
        hv = 1.0d-6
        xp = x + hx*xd; yp = y + hy*yd; wp = w4 + hw*w4d; vp = v2 + hv*v2d
        xm = x - hx*xd; ym = y - hy*yd; wm = w4 - hw*w4d; vm = v2 - hv*v2d
        call set01_lh045(xp, yp, wp, vp, xop, zp, wop)
        call set01_lh045(xm, ym, wm, vm, xom, zm, wom)
        xfd = (xop - xom)/(2.0d0*1.0d-6)
        zfd = (zp - zm)/(2.0d0*1.0d-6)
        wfd = (wop - wom)/(2.0d0*1.0d-6)
        if (max(abs(xod-xfd), abs(zd-zfd), abs(wod-wfd)) > 2.0d-7) error stop 11

        xs = -0.41d0
        zs = 0.73d0
        ws = -0.29d0
        call lh045_vjp(x, y, w4, v2, xo, xs, zs, ws, xb, yb, wb, vb)
        lhs = xs*xod + zs*zd + ws*wod
        rhs = xb*xd + yb*yd + wb*w4d + vb*v2d
        scale = max(1.0d0, abs(lhs), abs(rhs))
        if (abs(lhs-rhs) > 2.0d-13*scale) error stop 12
    end do
    print '(a)', 'oracle_status: pass'
end program test_lh045
