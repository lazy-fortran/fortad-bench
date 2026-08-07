program bench_tapenade_set01_lh025
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh025_case, only: set01_lh025
    use tapenade_set01_lh025_hand, only: lh025_jvp, lh025_vjp
    use lh025_forward_ad, only: lh025_jvp_generated => lh025_jvp
    use lh025_reverse_ad, only: lh025_vjp_generated => lh025_vjp
    implicit none

    integer, parameter :: n = 7, k = 3, m = n-k
    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp]
    real(dp) :: a(m,k), x(k), lambda, y(k)
    real(dp) :: ad(m,k), xd(k), lambdad, yd(k), zd(n)
    real(dp) :: y_hand(k), z_hand(n), yd_hand(k), zd_hand(n)
    real(dp) :: yb(k), ab(m,k), xb(k), lambdab
    real(dp) :: ab_hand(m,k), xb_hand(k), lambdab_hand
    real(dp) :: a_plus(m,k), a_minus(m,k), x_plus(k), x_minus(k)
    real(dp) :: y_plus(k), y_minus(k), lambda_plus, lambda_minus
    real(dp) :: fd, tangent, fd_errors(4), lhs, rhs
    integer :: i, j

    do i = 1, m
        do j = 1, k
            a(i,j) = 0.11_dp*real(i,dp) - 0.07_dp*real(j,dp) + 0.013_dp*i*j
            ad(i,j) = 0.02_dp*sin(real(2*i+j,dp))
        end do
    end do
    do j = 1, k
        x(j) = 0.4_dp + 0.17_dp*j
        xd(j) = -0.03_dp*cos(real(j,dp))
        yb(j) = 0.21_dp - 0.08_dp*j
    end do
    lambda = 1.35_dp
    lambdad = -0.12_dp

    call set01_lh025(a, x, lambda, y)
    call lh025_jvp(a, x, n, k, lambda, ad, xd, lambdad, y_hand, yd_hand, &
                   z_hand, zd_hand)
    call lh025_jvp_generated(a, ad, x, xd, lambda, lambdad, y, yd)
    call check_array("JVP primal y", y, y_hand)
    call check_array("JVP y", yd, yd_hand)

    ab = 0.0_dp
    xb = 0.0_dp
    lambdab = 0.0_dp
    call lh025_vjp(a, x, n, k, lambda, yb, ab_hand, xb_hand, lambdab_hand)
    call lh025_vjp_generated(a, x, lambda, y, yb, ab, xb, lambdab)
    call check_close("VJP A", maxval(abs(ab-ab_hand)), 0.0_dp)
    call check_array("VJP x", xb, xb_hand)
    call check_close("VJP lambda", lambdab, lambdab_hand)

    tangent = dot_product(yb, yd_hand)
    lhs = tangent
    rhs = sum(ab_hand*ad) + dot_product(xb_hand, xd) + lambdab_hand*lambdad
    call check_close("adjoint identity", lhs, rhs)

    do i = 1, size(steps)
        a_plus = a + steps(i)*ad
        a_minus = a - steps(i)*ad
        x_plus = x + steps(i)*xd
        x_minus = x - steps(i)*xd
        lambda_plus = lambda + steps(i)*lambdad
        lambda_minus = lambda - steps(i)*lambdad
        call set01_lh025(a_plus, x_plus, lambda_plus, y_plus)
        call set01_lh025(a_minus, x_minus, lambda_minus, y_minus)
        fd = dot_product(yb, y_plus-y_minus)/(2.0_dp*steps(i))
        fd_errors(i) = abs(fd-tangent)
    end do
    if (minval(fd_errors) > 3.0e-9_dp) error stop "lh025 finite difference failed"
    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "fd_errors:", fd_errors
    write (*, '(a,es24.16)') "adjoint_residual: ", abs(lhs-rhs)
contains
    subroutine check_close(label, actual, expected)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        if (abs(actual-expected) > 3.0e-11_dp*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh025 scalar mismatch"
        end if
    end subroutine check_close

    subroutine check_array(label, actual, expected)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual(:), expected(:)
        call check_close(label, maxval(abs(actual-expected)), 0.0_dp)
    end subroutine check_array
end program bench_tapenade_set01_lh025
