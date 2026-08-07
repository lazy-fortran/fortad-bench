program bench_tapenade_set01_lh031
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh031_case, only: set01_lh031
    use tapenade_set01_lh031_hand, only: lh031_jvp, lh031_vjp
    use lh031_forward_ad, only: generated_jvp => lh031_jvp
    use lh031_reverse_x, only: generated_vjp_x => lh031_vjp_x
    use lh031_reverse_y, only: generated_vjp_y => lh031_vjp_y
    use lh031_reverse_z, only: generated_vjp_z => lh031_vjp_z
    implicit none

    real(dp), parameter :: x = 0.7_dp, y = -0.2_dp, z = 1.1_dp
    real(dp), parameter :: xd = -0.04_dp, yd = 0.01_dp, zd = 0.02_dp
    real(dp), parameter :: xbar = 0.5_dp, ybar = -0.3_dp, zbar = 0.2_dp
    real(dp), parameter :: steps(4) = [1.0e-3_dp, 1.0e-4_dp, &
                                        1.0e-5_dp, 1.0e-6_dp]
    real(dp) :: xp, yp, zp, xm, ym, zm
    real(dp) :: x_out, y_out, z_out, x_out_hand, y_out_hand, z_out_hand
    real(dp) :: x_out_p, y_out_p, z_out_p
    real(dp) :: x_out_m, y_out_m, z_out_m
    real(dp) :: x_out_d, y_out_d, z_out_d
    real(dp) :: x_out_d_hand, y_out_d_hand, z_out_d_hand
    real(dp) :: xbar_hand, ybar_hand, zbar_hand
    real(dp) :: xbar_expected, ybar_expected, zbar_expected
    real(dp) :: xbar_x, ybar_x, zbar_x, xbar_y, ybar_y, zbar_y
    real(dp) :: xbar_z, ybar_z, zbar_z
    real(dp) :: tangent, fd, error, min_fd_error, lhs, rhs
    integer :: i

    call set01_lh031(x, y, z, x_out, y_out, z_out)
    call lh031_jvp(x, y, z, xd, yd, zd, x_out_hand, y_out_hand, z_out_hand, &
                   x_out_d_hand, y_out_d_hand, z_out_d_hand)
    call generated_jvp(x, xd, y, yd, z, zd, x_out, x_out_d, y_out, &
                       y_out_d, z_out, z_out_d)
    call check_close("primal x", x_out, x_out_hand)
    call check_close("primal y", y_out, y_out_hand)
    call check_close("primal z", z_out, z_out_hand)
    call check_close("jvp x", x_out_d, x_out_d_hand)
    call check_close("jvp y", y_out_d, y_out_d_hand)
    call check_close("jvp z", z_out_d, z_out_d_hand)

    call generated_vjp_x(x, y, z, x_out, y_out, z_out, 1.0_dp, &
                         xbar_x, ybar_x, zbar_x)
    call generated_vjp_y(x, y, z, x_out, y_out, z_out, 1.0_dp, &
                         xbar_y, ybar_y, zbar_y)
    call generated_vjp_z(x, y, z, x_out, y_out, z_out, 1.0_dp, &
                         xbar_z, ybar_z, zbar_z)
    call lh031_vjp(x, y, z, x_out, y_out, z_out, 1.0_dp, 0.0_dp, &
                   0.0_dp, xbar_expected, ybar_expected, zbar_expected)
    call check_close("vjp x seed x", xbar_x, xbar_expected)
    call check_close("vjp y seed x", ybar_x, ybar_expected)
    call check_close("vjp z seed x", zbar_x, zbar_expected)
    call lh031_vjp(x, y, z, x_out, y_out, z_out, 0.0_dp, 1.0_dp, &
                   0.0_dp, xbar_expected, ybar_expected, zbar_expected)
    call check_close("vjp x seed y", xbar_y, xbar_expected)
    call check_close("vjp y seed y", ybar_y, ybar_expected)
    call check_close("vjp z seed y", zbar_y, zbar_expected)
    call lh031_vjp(x, y, z, x_out, y_out, z_out, 0.0_dp, 0.0_dp, &
                   1.0_dp, xbar_expected, ybar_expected, zbar_expected)
    call check_close("vjp x seed z", xbar_z, xbar_expected)
    call check_close("vjp y seed z", ybar_z, ybar_expected)
    call check_close("vjp z seed z", zbar_z, zbar_expected)

    xbar_hand = xbar*xbar_x + ybar*xbar_y + zbar*xbar_z
    ybar_hand = xbar*ybar_x + ybar*ybar_y + zbar*ybar_z
    zbar_hand = xbar*zbar_x + ybar*zbar_y + zbar*zbar_z
    call lh031_vjp(x, y, z, x_out, y_out, z_out, xbar, ybar, zbar, &
                   xbar_expected, ybar_expected, zbar_expected)
    call check_close("combined vjp x", xbar_hand, xbar_expected)
    call check_close("combined vjp y", ybar_hand, ybar_expected)
    call check_close("combined vjp z", zbar_hand, zbar_expected)

    min_fd_error = huge(1.0_dp)
    tangent = xbar*x_out_d_hand + ybar*y_out_d_hand + zbar*z_out_d_hand
    do i = 1, size(steps)
        xp = x + steps(i)*xd
        yp = y + steps(i)*yd
        zp = z + steps(i)*zd
        xm = x - steps(i)*xd
        ym = y - steps(i)*yd
        zm = z - steps(i)*zd
        call set01_lh031(xp, yp, zp, x_out_p, y_out_p, z_out_p)
        call set01_lh031(xm, ym, zm, x_out_m, y_out_m, z_out_m)
        fd = (xbar*(x_out_p-x_out_m) + ybar*(y_out_p-y_out_m) + &
              zbar*(z_out_p-z_out_m))/(2.0_dp*steps(i))
        error = abs(fd-tangent)
        min_fd_error = min(min_fd_error, error)
    end do
    lhs = xbar*x_out_d_hand + ybar*y_out_d_hand + zbar*z_out_d_hand
    rhs = xd*xbar_hand + yd*ybar_hand + zd*zbar_hand
    call check_close("adjoint identity", lhs, rhs)
    if (min_fd_error > 3.0e-9_dp) error stop "lh031 finite difference failed"
    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_errors:", min_fd_error, 0.0_dp, &
                                   0.0_dp, 0.0_dp
    write (*, '(a,es24.16)') "adjoint_residual: ", abs(lhs-rhs)

contains
    subroutine check_close(label, actual, expected)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        if (abs(actual-expected) > 3.0e-11_dp*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh031 scalar mismatch"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh031
