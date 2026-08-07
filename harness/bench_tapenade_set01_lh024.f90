program bench_tapenade_set01_lh024
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh024_case, only: set01_lh024
    use tapenade_set01_lh024_hand, only: lh024_hand_jvp, lh024_hand_vjp
    use lh024_forward_ad, only: lh024_jvp
    implicit none

    real(dp), parameter :: steps(4) = [1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp, 1.0e-6_dp]
    real(dp) :: x0(100), y0(100), xd(100), yd(100)
    real(dp) :: x_port(100), y_port(100), x_hand(100), y_hand(100)
    real(dp) :: xd_hand(100), yd_hand(100), xd_ad(100), yd_ad(100)
    real(dp) :: x_plus(100), y_plus(100), x_minus(100), y_minus(100)
    real(dp) :: xb_seed(100), yb_seed(100), xb(100), yb(100)
    real(dp) :: wx(100), wy(100), fd, fd_errors(4), lhs, rhs
    real(dp) :: objective_plus, objective_minus, objective_base
    integer :: i, k

    do i = 1, 100
        x0(i) = 0.09_dp + 0.0007_dp*real(i, dp)
        y0(i) = 0.06_dp + 0.0005_dp*real(i, dp)
        xd(i) = 0.001_dp*sin(real(i, dp))
        yd(i) = 0.001_dp*cos(real(i, dp))
        wx(i) = 0.3_dp*sin(real(i, dp))
        wy(i) = 0.2_dp*cos(real(i, dp))
        xb_seed(i) = wx(i)
        yb_seed(i) = wy(i)
    end do

    x_port = x0
    y_port = y0
    call set01_lh024(x_port, y_port)
    call lh024_hand_jvp(x0, y0, xd, yd, x_hand, y_hand, xd_hand, yd_hand)
    call check_array(x_port, x_hand, 2.0e-12_dp, "independent primal x")
    call check_array(y_port, y_hand, 2.0e-12_dp, "independent primal y")

    x_port = x0
    y_port = y0
    xd_ad = xd
    yd_ad = yd
    call lh024_jvp(x_port, xd_ad, y_port, yd_ad)
    call check_array(x_port, x_hand, 2.0e-11_dp, "FortAD primal x")
    call check_array(y_port, y_hand, 2.0e-11_dp, "FortAD primal y")
    call check_array(xd_ad, xd_hand, 2.0e-11_dp, "FortAD JVP x")
    call check_array(yd_ad, yd_hand, 2.0e-11_dp, "FortAD JVP y")

    objective_base = dot_product(wx, x_hand) + dot_product(wy, y_hand)
    do k = 1, size(steps)
        x_plus = x0 + steps(k)*xd
        y_plus = y0 + steps(k)*yd
        x_minus = x0 - steps(k)*xd
        y_minus = y0 - steps(k)*yd
        call set01_lh024(x_plus, y_plus)
        call set01_lh024(x_minus, y_minus)
        objective_plus = dot_product(wx, x_plus) + dot_product(wy, y_plus)
        objective_minus = dot_product(wx, x_minus) + dot_product(wy, y_minus)
        fd = (objective_plus - objective_minus)/(2.0_dp*steps(k))
        fd_errors(k) = abs(fd - (dot_product(wx, xd_hand) + &
                                 dot_product(wy, yd_hand)))
    end do
    if (minval(fd_errors) > 2.0e-9_dp) then
        error stop "lh024 finite-difference sweep did not converge"
    end if

    call lh024_hand_vjp(x0, y0, xb_seed, yb_seed, xb, yb)
    lhs = dot_product(xb_seed, xd_hand) + dot_product(yb_seed, yd_hand)
    rhs = dot_product(xb, xd) + dot_product(yb, yd)
    call check_close(lhs, rhs, 2.0e-10_dp, "hand adjoint identity")

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_errors:", fd_errors
    write (*, '(a,es24.16)') "adjoint_residual: ", abs(lhs - rhs)
    write (*, '(a,es24.16)') "objective_base: ", objective_base
contains
    subroutine check_array(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual(:), expected(:), tolerance
        character(len=*), intent(in) :: label
        real(dp) :: scale

        scale = max(1.0_dp, maxval(abs(expected)))
        if (maxval(abs(actual - expected)) > tolerance*scale) then
            error stop trim(label)//" mismatch"
        end if
    end subroutine check_array

    subroutine check_close(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual, expected, tolerance
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            error stop trim(label)//" mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh024
