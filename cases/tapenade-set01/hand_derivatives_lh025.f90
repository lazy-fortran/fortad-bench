! SPDX-License-Identifier: MIT
! Independent closed-form oracle for the bounded lh025 port.
module tapenade_set01_lh025_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh025_jvp(a, x, n, k, lambda, ad, xd, lambdad, y, yd, z, zd)
        integer, intent(in) :: n, k
        real(dp), intent(in) :: a(n-k, k), x(k), lambda
        real(dp), intent(in) :: ad(n-k, k), xd(k), lambdad
        real(dp), intent(out) :: y(k), yd(k), z(n), zd(n)
        real(dp) :: zdense(n-k), zdense_d(n-k)
        integer :: i, j

        do i = 1, n-k
            zdense(i) = 0.0_dp
            zdense_d(i) = 0.0_dp
            do j = 1, k
                zdense(i) = zdense(i) + a(i, j)*x(j)
                zdense_d(i) = zdense_d(i) + ad(i, j)*x(j) + a(i, j)*xd(j)
            end do
            z(i) = zdense(i)
            zd(i) = zdense_d(i)
        end do
        do i = 1, k
            z(n-k+i) = lambda*x(i)
            zd(n-k+i) = lambdad*x(i) + lambda*xd(i)
        end do

        do j = 1, k
            y(j) = lambda*z(n-k+j)
            yd(j) = lambdad*z(n-k+j) + lambda*zd(n-k+j)
            do i = 1, n-k
                y(j) = y(j) + a(i, j)*zdense(i)
                yd(j) = yd(j) + ad(i, j)*zdense(i) + a(i, j)*zdense_d(i)
            end do
        end do
    end subroutine lh025_jvp

    subroutine lh025_vjp(a, x, n, k, lambda, yb, ab, xb, lambdab)
        integer, intent(in) :: n, k
        real(dp), intent(in) :: a(n-k, k), x(k), lambda, yb(k)
        real(dp), intent(out) :: ab(n-k, k), xb(k), lambdab
        real(dp) :: z(n-k), zbar(n-k)
        integer :: i, j

        do i = 1, n-k
            z(i) = 0.0_dp
            do j = 1, k
                z(i) = z(i) + a(i, j)*x(j)
            end do
        end do
        do i = 1, n-k
            zbar(i) = 0.0_dp
            do j = 1, k
                zbar(i) = zbar(i) + a(i, j)*yb(j)
            end do
        end do
        do i = 1, n-k
            do j = 1, k
                ab(i, j) = z(i)*yb(j) + zbar(i)*x(j)
            end do
        end do
        do j = 1, k
            xb(j) = lambda*lambda*yb(j)
            do i = 1, n-k
                xb(j) = xb(j) + a(i, j)*zbar(i)
            end do
        end do
        lambdab = 0.0_dp
        do j = 1, k
            lambdab = lambdab + 2.0_dp*lambda*x(j)*yb(j)
        end do
    end subroutine lh025_vjp
end module tapenade_set01_lh025_hand
