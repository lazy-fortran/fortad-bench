program bench_tapenade_set01_lh086
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh086_forward_ad, only: lh086_jvp_generated => lh086_jvp
    use lh086_reverse_ad, only: lh086_vjp_generated => lh086_vjp
    use tapenade_set01_lh086_hand, only: lh086_jvp_hand => lh086_jvp, &
        lh086_vjp_hand => lh086_vjp, primal_lh086
    implicit none

    logical :: ok
    real(dp) :: x, xd, alpha, alphad, y, yd, yh, ydh
    real(dp) :: yb, xb, alphab, xbh, alphabh, h, yp, ym, fd
    integer :: step
    integer, parameter :: n = 6

    ok = .true.
    x = 1.2_dp
    xd = 0.4_dp
    alpha = 0.8_dp
    alphad = -0.3_dp
    yb = 0.7_dp

    call lh086_jvp_generated(x, xd, n, alpha, alphad, y, yd)
    call lh086_jvp_hand(x, xd, n, alpha, alphad, yh, ydh)
    call check_close("lh086 primal", y, yh, ok)
    call check_close("lh086 JVP", yd, ydh, ok)

    call lh086_vjp_generated(x, n, alpha, y, yb, xb, alphab)
    call lh086_vjp_hand(x, n, alpha, yb, xbh, alphabh)
    call check_close("lh086 x VJP", xb, xbh, ok)
    call check_close("lh086 alpha VJP", alphab, alphabh, ok)
    call check_close("lh086 adjoint identity", xb*xd + alphab*alphad, &
        yb*ydh, ok)

    do step = 2, 5
        h = 10.0_dp**(-step)
        call primal_lh086(x + h*xd, n, alpha + h*alphad, yp)
        call primal_lh086(x - h*xd, n, alpha - h*alphad, ym)
        fd = (yp - ym)/(2.0_dp*h)
        call check_close_tol("lh086 finite difference", fd, ydh, 1.0e-6_dp, ok)
    end do

    if (.not. ok) error stop "Tapenade set01 lh086 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        logical, intent(inout) :: ok

        if (abs(actual - expected) > 2.0e-11_dp*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_close_tol(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance
        logical, intent(inout) :: ok

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close_tol

end program bench_tapenade_set01_lh086
