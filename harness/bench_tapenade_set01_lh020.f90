program bench_tapenade_set01_lh020
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh020_case, only: set01_lh020
    use tapenade_set01_lh020_hand, only: lh020_hand
    use lh020_forward_ad, only: lh020_jvp
    use lh020_reverse_ad, only: lh020_vjp
    implicit none

    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp]
    integer, parameter :: n_values(2) = [1, 3]
    real(dp) :: x(4), y(4), dx(4), dy(4), seed
    real(dp) :: x1_out, x1_hand, x1_jvp, x1_reverse
    real(dp) :: jvp, jvp_hand, seed_x_b(4), seed_y_b(4)
    real(dp) :: x_b(4), y_b(4), x1_plus, x1_minus, fd
    real(dp) :: fd_errors(4), lhs, rhs, max_fd_error, max_adjoint_residual
    integer :: branch, branch_hand, branch_jvp, branch_reverse, n, i, k

    x = [1.1_dp, -0.4_dp, 0.8_dp, 1.7_dp]
    y = [0.6_dp, 1.3_dp, -0.9_dp, 0.2_dp]
    dx = [-0.07_dp, 0.03_dp, -0.02_dp, 0.05_dp]
    dy = [0.04_dp, -0.01_dp, 0.06_dp, -0.03_dp]
    seed = -0.8_dp
    max_fd_error = 0.0_dp
    max_adjoint_residual = 0.0_dp

    do i = 1, size(n_values)
        n = n_values(i)
        call lh020_hand(x, y, n, dx, dy, seed, x1_hand, branch_hand, &
                        jvp_hand, seed_x_b, seed_y_b)
        call set01_lh020(x, y, n, x1_out, branch)
        call check_close(x1_out, x1_hand, 2.0e-12_dp, "primal")
        if (branch /= branch_hand) error stop "lh020 branch mismatch"

        call lh020_jvp(x, dx, y, dy, n, x1_jvp, jvp, branch_jvp)
        call check_close(x1_jvp, x1_hand, 2.0e-12_dp, "JVP primal")
        call check_close(jvp, jvp_hand, 2.0e-12_dp, "JVP")
        if (branch_jvp /= branch_hand) error stop "lh020 JVP branch mismatch"

        call lh020_vjp(x, y, n, x1_reverse, branch_reverse, seed, x_b, y_b)
        call check_close(x1_reverse, x1_hand, 2.0e-12_dp, "VJP primal")
        if (maxval(abs(x_b - seed_x_b)) > 2.0e-12_dp) then
            error stop "lh020 x VJP mismatch"
        end if
        if (maxval(abs(y_b - seed_y_b)) > 2.0e-12_dp) then
            error stop "lh020 y VJP mismatch"
        end if

        do k = 1, size(steps)
            call set01_lh020(x + steps(k)*dx, y + steps(k)*dy, n, &
                             x1_plus, branch)
            call set01_lh020(x - steps(k)*dx, y - steps(k)*dy, n, &
                             x1_minus, branch)
            fd = (x1_plus - x1_minus)/(2.0_dp*steps(k))
            fd_errors(k) = abs(fd - jvp_hand)
        end do
        max_fd_error = max(max_fd_error, maxval(fd_errors))
        if (minval(fd_errors) > 2.0e-10_dp) then
            error stop "lh020 finite-difference sweep did not converge"
        end if

        lhs = seed*jvp
        rhs = dot_product(x_b, dx) + dot_product(y_b, dy)
        max_adjoint_residual = max(max_adjoint_residual, abs(lhs - rhs))
        call check_close(lhs, rhs, 2.0e-12_dp, "adjoint identity")
    end do

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,es24.16)') "max_fd_error: ", max_fd_error
    write (*, '(a,es24.16)') "max_adjoint_residual: ", max_adjoint_residual
contains
    subroutine check_close(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual, expected, tolerance
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh020 scalar mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh020
