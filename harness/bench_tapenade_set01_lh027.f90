program bench_tapenade_set01_lh027
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh027_case, only: set01_lh027
    use tapenade_set01_lh027_hand, only: lh027_hand
    use lh027_forward_ad, only: lh027_jvp
    use lh027_reverse_ad, only: lh027_vjp
    implicit none

    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp]
    real(dp) :: a(100), b(100), a_d(100), b_d(100), a_out(100), b_out(100)
    real(dp) :: objective, objective_d, objective_seed
    real(dp) :: a_out_d(100), b_out_d(100)
    real(dp) :: a_out_hand(100), b_out_hand(100), objective_hand
    real(dp) :: a_out_d_hand(100), b_out_d_hand(100), objective_d_hand
    real(dp) :: a_b(100), b_b(100), a_b_hand(100), b_b_hand(100)
    real(dp) :: a_plus(100), b_plus(100), a_minus(100)
    real(dp) :: b_minus(100), a_out_plus(100), b_out_plus(100)
    real(dp) :: a_out_minus(100), b_out_minus(100), objective_plus
    real(dp) :: objective_minus, fd_a(4), fd_b(4), fd_objective(4)
    real(dp) :: lhs, rhs, residual
    integer :: i, k

    do i = 1, 100
        a(i) = 0.75_dp + 0.011_dp*real(i, dp)
        b(i) = 1.10_dp + 0.017_dp*real(i, dp)
        a_d(i) = 0.03_dp*sin(real(i, dp))
        b_d(i) = -0.02_dp*cos(real(i, dp))
    end do
    objective_seed = -0.37_dp

    call lh027_hand(a, b, a_d, b_d, a_out_hand, b_out_hand, objective_hand, &
                    a_out_d_hand, b_out_d_hand, objective_d_hand, &
                    objective_seed, a_b_hand, b_b_hand)
    call set01_lh027(a, b, a_out, b_out, objective)
    call lh027_jvp(a, a_d, b, b_d, a_out, a_out_d, b_out, b_out_d, &
                   objective, objective_d)
    call lh027_vjp(a, b, a_out, b_out, objective_seed, a_b, b_b)

    call check_array(a_out, a_out_hand, 2.0e-12_dp, "primal a")
    call check_array(b_out, b_out_hand, 2.0e-12_dp, "primal b")
    call check_close(objective, objective_hand, 2.0e-12_dp, "objective")
    call check_array(a_out_d, a_out_d_hand, 2.0e-12_dp, "JVP a")
    call check_array(b_out_d, b_out_d_hand, 2.0e-12_dp, "JVP b")
    call check_close(objective_d, objective_d_hand, 2.0e-12_dp, "JVP objective")
    call check_array(a_b, a_b_hand, 2.0e-12_dp, "VJP a")
    call check_array(b_b, b_b_hand, 2.0e-12_dp, "VJP b")

    do k = 1, size(steps)
        a_plus = a + steps(k)*a_d
        b_plus = b + steps(k)*b_d
        a_minus = a - steps(k)*a_d
        b_minus = b - steps(k)*b_d
        call set01_lh027(a_plus, b_plus, a_out_plus, b_out_plus, objective_plus)
        call set01_lh027(a_minus, b_minus, a_out_minus, b_out_minus, objective_minus)
        fd_a(k) = maxval(abs((a_out_plus - a_out_minus)/(2.0_dp*steps(k)) &
                             - a_out_d_hand))
        fd_b(k) = maxval(abs((b_out_plus - b_out_minus)/(2.0_dp*steps(k)) &
                             - b_out_d_hand))
        fd_objective(k) = abs((objective_plus - objective_minus) / &
                              (2.0_dp*steps(k)) - objective_d_hand)
    end do
    if (minval(fd_a) > 2.0e-10_dp .or. minval(fd_b) > 2.0e-10_dp .or. &
        minval(fd_objective) > 2.0e-10_dp) then
        error stop "lh027 finite-difference sweep did not converge"
    end if

    lhs = objective_seed*objective_d_hand
    rhs = dot_product(a_b, a_d) + dot_product(b_b, b_d)
    residual = abs(lhs - rhs)
    if (residual > 2.0e-12_dp*max(1.0_dp, abs(lhs))) then
        error stop "lh027 adjoint identity failed"
    end if

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_a_errors:", fd_a
    write (*, '(a,4(1x,es12.4))') "fd_b_errors:", fd_b
    write (*, '(a,4(1x,es12.4))') "fd_objective_errors:", fd_objective
    write (*, '(a,es24.16)') "adjoint_residual: ", residual
contains
    subroutine check_array(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual(:), expected(:), tolerance
        character(len=*), intent(in) :: label

        if (maxval(abs(actual - expected)) > &
            tolerance*max(1.0_dp, maxval(abs(expected)))) then
            write (*, '(a,es24.16)') trim(label)//" max error: ", &
                maxval(abs(actual - expected))
            error stop "lh027 array mismatch"
        end if
    end subroutine check_array

    subroutine check_close(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual, expected, tolerance
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh027 scalar mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh027
