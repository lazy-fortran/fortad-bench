program bench_tapenade_set06_v234
    use tapenade_set06_v234_hand, only: primal_v234, v234_jvp, v234_vjp
    use v234_forward_ad, only: v234_jvp_generated => v234_jvp
    use v234_reverse_ad, only: v234_vjp_generated => v234_vjp
    implicit none

    logical :: ok
    real :: t, td, f, fd, fh, fdh, fb, tb, tbh, h, fp, fm, finite_difference
    integer :: step

    ok = .true.
    t = 1.25
    td = -0.4
    fb = 0.7

    call v234_jvp_generated(t, td, f, fd)
    call v234_jvp(t, td, fh, fdh)
    call check_close("v234 primal", f, fh, ok)
    call check_close("v234 JVP", fd, fdh, ok)

    call v234_vjp_generated(t, f, fb, tb)
    call v234_vjp(t, fb, tbh)
    call check_close("v234 VJP", tb, tbh, ok)
    call check_close("v234 adjoint identity", tb*td, fb*fdh, ok)

    do step = 1, 2
        h = 10.0**(-step)
        call primal_v234(t + h*td, fp)
        call primal_v234(t - h*td, fm)
        finite_difference = (fp - fm)/(2.0*h)
        call check_close_tol("v234 finite difference", finite_difference, fdh, 2.0e-4, ok)
    end do

    if (.not. ok) error stop "Tapenade set06 v234 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual, expected
        logical, intent(inout) :: ok

        if (abs(actual - expected) > 2.0e-5*max(1.0, abs(expected))) then
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

end program bench_tapenade_set06_v234
