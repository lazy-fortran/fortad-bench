program bench_tapenade_set01_lh018
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh018_case, only: set01_lh018
    use tapenade_set01_lh018_hand, only: lh018_hand
    use lh018_forward_ad, only: lh018_jvp
    use lh018_reverse_ad, only: lh018_vjp
    implicit none

    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp]
    real(dp) :: b, direction_b, seed, a_out, a_plus, a_minus
    real(dp) :: b_b, b_b_hand, c(20), direction_c(20), c_b(20), c_b_hand(20)
    real(dp) :: jvp, jvp_hand, vjp_b, vjp_c(20), vjp_b_hand, vjp_c_hand(20)
    real(dp) :: fd, fd_errors(4), lhs, rhs
    integer :: i, k

    b = 1.2_dp
    direction_b = -0.07_dp
    seed = -0.8_dp
    do i = 1, 20
        c(i) = 0.7_dp + 0.013_dp*real(i, dp)
        direction_c(i) = 0.02_dp*sin(real(i, dp))
    end do

    call set01_lh018(b, c, a_out)
    call lh018_hand(b, c, direction_b, direction_c, seed, a_out, jvp_hand, &
                    b_b_hand, c_b_hand)
    call lh018_jvp(b, direction_b, c, direction_c, a_out, jvp)
    call lh018_vjp(b, c, a_out, seed, b_b, c_b)
    call check_close(a_out, 343.0_dp*b*c(10), 2.0e-12_dp, "primal")
    call check_close(jvp, jvp_hand, 2.0e-12_dp, "JVP")
    call check_close(b_b, b_b_hand, 2.0e-12_dp, "b VJP")
    if (maxval(abs(c_b - c_b_hand)) > 2.0e-12_dp) then
        error stop "lh018 c VJP mismatch"
    end if

    do k = 1, size(steps)
        call set01_lh018(b + steps(k)*direction_b, &
                         c + steps(k)*direction_c, a_plus)
        call set01_lh018(b - steps(k)*direction_b, &
                         c - steps(k)*direction_c, a_minus)
        fd = (a_plus - a_minus)/(2.0_dp*steps(k))
        fd_errors(k) = abs(fd - jvp_hand)
    end do
    if (minval(fd_errors) > 2.0e-10_dp) then
        error stop "lh018 finite-difference sweep did not converge"
    end if
    lhs = seed*jvp
    rhs = b_b*direction_b + dot_product(c_b, direction_c)
    call check_close(lhs, rhs, 2.0e-12_dp, "adjoint identity")
    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_errors:", fd_errors
    write (*, '(a,es24.16)') "adjoint_residual: ", abs(lhs - rhs)
contains
    subroutine check_close(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual, expected, tolerance
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh018 scalar mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh018
