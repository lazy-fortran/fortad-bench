program bench_tapenade_set01_lh011
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh011_oracle, only: bounded_model, objective, &
                                            hand_jvp, hand_vjp
    implicit none

    integer, parameter :: n = 100
    integer, parameter :: selector_values(5) = [0, 1, 2, 3, 10]
    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, &
                                       1.0e-4_dp, 1.0e-5_dp]
    real(dp) :: x(n), direction(n), weight(n), output(n), expected(n)
    real(dp) :: jvp, vjp(n), seed, plus, minus, finite_difference
    real(dp) :: lhs, rhs
    real(dp) :: fd_errors(4), max_fd_error, adjoint_residual
    real(dp) :: gradient(n)
    integer :: i, k, selector

    do i = 1, n
        x(i) = 0.25_dp + 0.01_dp*real(i, dp)
        direction(i) = sin(0.13_dp*real(i, dp))
        weight(i) = -0.4_dp + 0.017_dp*real(i, dp)
    end do
    seed = -0.75_dp
    max_fd_error = 0.0_dp
    adjoint_residual = 0.0_dp

    do k = 1, size(selector_values)
        selector = selector_values(k)
        output = x
        call bounded_model(selector, output)
        expected = x
        if (selector == 2) then
            expected(3) = 10.0_dp
        else
            expected(2) = 10.0_dp
        end if
        expected(4) = 10.0_dp
        if (maxval(abs(output - expected)) > 2.0e-14_dp) then
            error stop "lh011 bounded control-flow model mismatch"
        end if

        call hand_jvp(selector, direction, weight, jvp)
        call hand_vjp(selector, seed, weight, gradient)
        vjp = gradient
        lhs = seed*jvp
        rhs = dot_product(vjp, direction)
        adjoint_residual = max(adjoint_residual, abs(lhs - rhs))
        if (adjoint_residual > 2.0e-13_dp) then
            error stop "lh011 bounded adjoint identity failed"
        end if

        do i = 1, size(steps)
            call objective(selector, x + steps(i)*direction, weight, plus)
            call objective(selector, x - steps(i)*direction, weight, minus)
            finite_difference = (plus - minus)/(2.0_dp*steps(i))
            fd_errors(i) = abs(finite_difference - jvp)
        end do
        max_fd_error = max(max_fd_error, maxval(fd_errors))
        if (maxval(fd_errors) > 1.0e-8_dp) then
            error stop "lh011 bounded central differences failed"
        end if
    end do

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,5(1x,i0))') "bounded_selectors:", selector_values
    write (*, '(a,es24.16)') "hand_jvp: ", jvp
    write (*, '(a,es24.16)') "max_fd_error: ", max_fd_error
    write (*, '(a,es24.16)') "adjoint_residual: ", adjoint_residual
    write (*, '(a,es24.16)') "vjp_checksum: ", sum(vjp)
end program bench_tapenade_set01_lh011
