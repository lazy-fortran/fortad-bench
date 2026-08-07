program bench_tapenade_set01_lh034
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh034_case, only: set01_lh034
    use tapenade_set01_lh034_hand, only: lh034_hand_jvp, lh034_hand_vjp
    use lh034_forward_mod, only: lh034_forward
    implicit none

    real(dp), parameter :: steps(4) = [1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp, 1.0e-6_dp]
    real(dp), parameter :: a0 = 0.1_dp, b0 = 2.0_dp, x = 2.0_dp
    real(dp), parameter :: a0_d = 0.13_dp, b0_d = -0.08_dp
    real(dp), parameter :: root_b = 1.7_dp
    integer, parameter :: n = 18
    real(dp) :: root, root_hand, root_d, root_d_hand
    real(dp) :: a0_b, b0_b
    real(dp) :: root_plus, root_minus, fd, fd_errors(size(steps))
    real(dp) :: lhs, rhs, adjoint_residual
    integer :: k

    call set01_lh034(a0, b0, x, n, root)
    call lh034_hand_jvp(a0, a0_d, b0, b0_d, x, n, root_hand, &
                        root_d_hand)
    call lh034_forward(a0, a0_d, b0, b0_d, x, n, root, root_d)
    call check_close(root, root_hand, 2.0e-14_dp, "primal")
    call check_close(root_d, root_d_hand, 2.0e-13_dp, "JVP")

    do k = 1, size(steps)
        call set01_lh034(a0 + steps(k)*a0_d, b0 + steps(k)*b0_d, x, n, &
                         root_plus)
        call set01_lh034(a0 - steps(k)*a0_d, b0 - steps(k)*b0_d, x, n, &
                         root_minus)
        fd = (root_plus - root_minus)/(2.0_dp*steps(k))
        fd_errors(k) = abs(fd - root_d_hand)
    end do
    if (minval(fd_errors) > 2.0e-10_dp) then
        error stop "lh034 finite-difference sweep did not converge"
    end if

    call lh034_hand_vjp(a0, b0, x, n, root, root_b, a0_b, b0_b)
    lhs = root_b*root_d_hand
    rhs = a0_b*a0_d + b0_b*b0_d
    adjoint_residual = abs(lhs - rhs)
    call check_close(lhs, rhs, 2.0e-13_dp, "adjoint identity")

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_errors:", fd_errors
    write (*, '(a,es24.16)') "adjoint_residual: ", adjoint_residual
contains
    subroutine check_close(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual, expected, tolerance
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh034 oracle mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh034
