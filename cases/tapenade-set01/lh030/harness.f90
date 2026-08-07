program bench_tapenade_set01_lh030
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh030_case, only: set01_lh030
    use tapenade_set01_lh030_hand, only: value_gradient, jvp_hand => jvp
    use lh030_forward_ad, only: jvp_generated => lh030_forward
    use lh030_reverse_ad, only: vjp_generated => lh030_reverse
    implicit none

    real(dp), parameter :: x1 = 0.55_dp, x2 = 0.35_dp
    real(dp), parameter :: dx1 = -0.17_dp, dx2 = 0.29_dp
    real(dp), parameter :: seed = 0.73_dp
    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, &
                                       1.0e-4_dp, 1.0e-5_dp]
    real(dp) :: y, y_hand, yd, yd_hand, y_vjp
    real(dp) :: g1, g2, x1b, x2b, fd, fd_errors(4)
    real(dp) :: y_plus, y_minus, x1_plus, x2_plus, x1_minus, x2_minus
    integer :: i

    call set01_lh030(x1, x2, y)
    call value_gradient(x1, x2, y_hand, g1, g2)
    call check_close("primal", y, y_hand, 2.0e-12_dp)

    call jvp_hand(x1, x2, dx1, dx2, y_hand, yd_hand)
    call jvp_generated(x1, dx1, x2, dx2, y, yd)
    call check_close("forward primal", y, y_hand, 2.0e-12_dp)
    call check_close("forward tangent", yd, yd_hand, 2.0e-11_dp)

    call vjp_generated(x1, x2, y_vjp, seed, x1b, x2b)
    call check_close("reverse primal", y_vjp, y_hand, 2.0e-12_dp)
    call check_close("reverse i1", x1b, seed*g1, 2.0e-11_dp)
    call check_close("reverse i2", x2b, seed*g2, 2.0e-11_dp)
    call check_close("adjoint identity", seed*yd_hand, &
                     x1b*dx1 + x2b*dx2, 2.0e-11_dp)

    do i = 1, size(steps)
        x1_plus = x1 + steps(i)*dx1
        x1_minus = x1 - steps(i)*dx1
        x2_plus = x2 + steps(i)*dx2
        x2_minus = x2 - steps(i)*dx2
        call set01_lh030(x1_plus, x2_plus, y_plus)
        call set01_lh030(x1_minus, x2_minus, y_minus)
        fd = (y_plus-y_minus)/(2.0_dp*steps(i))
        fd_errors(i) = abs(fd-yd_hand)
    end do
    if (minval(fd_errors) > 2.0e-9_dp) error stop "lh030 finite difference failed"

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_errors:", fd_errors
    write (*, '(a,es24.16)') "adjoint_residual: ", &
        abs(seed*yd_hand-(x1b*dx1+x2b*dx2))
contains
    subroutine check_close(label, actual, expected, tolerance)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance

        if (abs(actual-expected) > tolerance*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh030 numerical mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh030
