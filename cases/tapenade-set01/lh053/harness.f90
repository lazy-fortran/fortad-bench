program lh053_harness
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh053_forward_mod, only: lh053_f
    implicit none

    integer, parameter :: nc = 3
    real(dp) :: z(nc), zd(nc), gamai(nc), gamai_d(nc)
    real(dp) :: v(nc), vd(nc), w(nc), wd(nc)
    real(dp) :: g(nc, nc), gd(nc, nc), tau(nc, nc), taud(nc, nc)
    real(dp), parameter :: expected(3) = [ &
        1.2664393900926276_dp, 1.2199482689426329_dp, 1.1530838481218995_dp]
    real(dp), parameter :: expected_d(3) = [ &
        0.022260233990125153_dp, 0.06429963641119894_dp, &
        -0.011910854284109968_dp]
    real(dp) :: tk, tkd, rcal, rcald

    z = [1.2_dp, 1.8_dp, 2.4_dp]
    zd = [0.15_dp, -0.2_dp, 0.35_dp]
    tk = 0.7_dp
    tkd = -0.11_dp
    rcal = 1.3_dp
    rcald = 0.08_dp
    call lh053_f(nc, z, zd, tk, tkd, rcal, rcald, gamai, gamai_d, &
        v, vd, w, wd, g, gd, tau, taud)
    if (maxval(abs(gamai - expected)) > 5.0e-12_dp) error stop "primal mismatch"
    if (maxval(abs(gamai_d - expected_d)) > 5.0e-12_dp) error stop "JVP mismatch"
    if (any(gamai /= gamai) .or. any(gamai_d /= gamai_d)) error stop "nonfinite"
    print '(a)', 'harness_status: pass'
    print '(a,es24.16)', 'gamai_1: ', gamai(1)
    print '(a,es24.16)', 'gamai_d_1: ', gamai_d(1)
end program lh053_harness
