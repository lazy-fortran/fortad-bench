program bench_tapenade_set01_bd05
    use bd05_forward, only: bd05_jvp_generated => bd05_jvp
    use bd05_reverse, only: bd05_vjp_generated => bd05_vjp
    use tapenade_set01_bd05_hand, only: bd05_hand_jvp, bd05_hand_vjp, bd05_primal
    implicit none

    real :: a(10), ad(10), b, bd, c, cd, ao(10), aod(10)
    real :: coh(10), cohd(10), co, cod, cohc, cohdc
    real :: seed, ab(10), bb, cb, abh(10), bbh, cbh
    real :: ap, am, h, fd, lhs, rhs
    logical :: ok
    integer :: step

    a = [0.3, -0.4, 0.7, 1.1, -0.8, 0.2, 0.9, -1.2, 0.5, 0.6]
    ad = [-0.2, 0.1, 0.4, -0.3, 0.5, -0.6, 0.2, 0.7, -0.1, 0.8]
    b = 1.25
    bd = -0.35
    c = 0.9
    cd = 0.45
    seed = -0.73
    ok = .true.

    call bd05_jvp_generated(a, ad, b, bd, c, cd, ao, aod, co, cod)
    call bd05_hand_jvp(a, ad, b, bd, c, cd, coh, cohd, cohc, cohdc)
    call check_array("JVP output", ao, coh, ok)
    call check_array("JVP output tangent", aod, cohd, ok)
    call check_close("JVP primal", co, cohc, ok)
    call check_close("JVP tangent", cod, cohdc, ok)

    call bd05_vjp_generated(a, b, c, ao, co, seed, ab, bb, cb)
    call bd05_hand_vjp(a, b, c, ao, co, seed, abh, bbh, cbh)
    call check_array("VJP A", ab, abh, ok)
    call check_close("VJP B", bb, bbh, ok)
    call check_close("VJP C", cb, cbh, ok)
    lhs = seed * cohdc
    rhs = sum(ab * ad) + bb * bd + cb * cd
    call check_close("adjoint identity", lhs, rhs, ok)

    do step = 2, 4
        h = 10.0**(-step)
        call bd05_primal(a + h*ad, b + h*bd, c + h*cd, ao, ap)
        call bd05_primal(a - h*ad, b - h*bd, c - h*cd, ao, am)
        fd = (ap - am)/(2.0*h)
        call check_close_tol("central difference", fd, cohdc, 3.0e-3, ok)
    end do

    if (.not. ok) error stop "Tapenade set01 bd05 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual, expected
        logical, intent(inout) :: ok
        if (abs(actual - expected) > 4.0e-4*max(1.0, abs(expected))) then
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

    subroutine check_array(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual(:), expected(:)
        logical, intent(inout) :: ok
        if (maxval(abs(actual - expected)) > 4.0e-4*max(1.0, maxval(abs(expected)))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), maxval(abs(actual - expected)), &
                maxval(abs(expected))
            ok = .false.
        end if
    end subroutine check_array

end program bench_tapenade_set01_bd05
