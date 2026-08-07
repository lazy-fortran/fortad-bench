program bench_tapenade_set04_lh110
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh110_forward_ad, only: set04_lh110_jvp_generated => set04_lh110_jvp
    use lh110_reverse_ad, only: set04_lh110_vjp_generated => set04_lh110_vjp
    use tapenade_set04_lh110_hand, only: set04_lh110_jvp_hand => set04_lh110_jvp, &
        set04_lh110_vjp_hand => set04_lh110_vjp, set04_lh110_primal
    implicit none

    logical :: ok
    real(dp) :: x, xd, y, yd, yh, ydh, yb, xb, xbh
    real(dp) :: h, yp, ym, fd
    integer :: step

    ok = .true.
    x = 2.25_dp
    xd = -0.35_dp
    yb = 0.8_dp

    call set04_lh110_jvp_generated(x, xd, y, yd)
    call set04_lh110_jvp_hand(x, xd, yh, ydh)
    call check_close("lh110 primal", y, yh, ok)
    call check_close("lh110 JVP", yd, ydh, ok)

    call set04_lh110_vjp_generated(x, y, yb, xb)
    call set04_lh110_vjp_hand(x, y, yb, xbh)
    call check_close("lh110 VJP", xb, xbh, ok)
    call check_close("lh110 adjoint identity", xb*xd, yb*ydh, ok)

    do step = 2, 5
        h = 10.0_dp**(-step)
        call set04_lh110_primal(x + h*xd, yp)
        call set04_lh110_primal(x - h*xd, ym)
        fd = (yp - ym)/(2.0_dp*h)
        call check_close_tol("lh110 finite difference", fd, ydh, 1.0e-8_dp, ok)
    end do

    if (.not. ok) error stop "Tapenade set04 lh110 oracle failed"
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

end program bench_tapenade_set04_lh110
