program lh051_harness
    use tapenade_set01_lh051_hand, only: hand_jvp
    use lh051_jvp_mod, only: lh051_jvp
    implicit none
    integer, parameter :: n = 60
    integer, parameter :: size = 2*n
    real :: xh(size), yh(size), zh(size), xhd(size), yhd(size), zhd(size)
    real :: xg(size), yg(size), zg(size), xgd(size), ygd(size), zgd(size)
    real :: error
    integer :: i

    do i = 1, size
        xh(i) = 0.17 + 0.013*i
        yh(i) = -0.31 + 0.009*i
        zh(i) = 0.23 - 0.011*i
        xhd(i) = 0.003 - 0.0007*i
        yhd(i) = -0.002 + 0.0005*i
        zhd(i) = 0.001 + 0.0004*i
    end do
    xg = xh
    yg = yh
    zg = zh
    xgd = xhd
    ygd = yhd
    zgd = zhd

    call hand_jvp(xh, yh, zh, n, 0, xhd, yhd, zhd)
    call lh051_jvp(xg, xgd, yg, ygd, zg, zgd, n, 0)
    error = max(maxval(abs(xh - xg)), maxval(abs(yh - yg)))
    error = max(error, maxval(abs(zh - zg)))
    error = max(error, maxval(abs(xhd - xgd)))
    error = max(error, maxval(abs(yhd - ygd)))
    error = max(error, maxval(abs(zhd - zgd)))
    if (error > 5.0e-5) error stop 1
    write (*, '(a,es12.4)') 'oracle_status: pass max_harness_error=', error
end program lh051_harness
