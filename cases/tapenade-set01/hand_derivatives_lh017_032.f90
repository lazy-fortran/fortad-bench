! SPDX-License-Identifier: MIT
! Independent piecewise hand derivatives for the set01 tranche L ports.
module tapenade_set01_tranche_l_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh017_jvp(a1, a1d, a2, a2d, branch, b1, b1d, b2, b2d)
        real(dp), intent(in) :: a1, a1d, a2, a2d
        integer, intent(in) :: branch
        real(dp), intent(out) :: b1, b1d, b2, b2d
        real(dp) :: x, xd

        x = a1**2
        xd = 2.0_dp*a1*a1d
        b1 = 5.0_dp
        b1d = 0.0_dp
        b2 = 18.0_dp
        b2d = 0.0_dp
        if (branch > 37) then
            b1 = x*a2+a1
            b1d = xd*a2+x*a2d+a1d
        else
            b2 = x*a1
            b2d = xd*a1+x*a1d
        end if
    end subroutine lh017_jvp

    subroutine lh022_primal(x, y)
        real(dp), intent(inout) :: x(100), y(100)
        real(dp) :: v1, v2
        integer :: i

        do i = 1, 100
            v1 = (x(i)+y(i))/2.0_dp
            v2 = x(i)*y(i)
            x(i) = v1+v2
            v1 = v1*v2
            y(i) = v1*v2
            y(i) = y(i)*x(i)
        end do
    end subroutine lh022_primal

    subroutine lh022_jvp(x, xd, y, yd)
        real(dp), intent(inout) :: x(100), xd(100), y(100), yd(100)
        real(dp) :: v1, v1d, v2, v2d
        integer :: i

        do i = 1, 100
            v1d = (xd(i)+yd(i))/2.0_dp
            v1 = (x(i)+y(i))/2.0_dp
            v2d = y(i)*xd(i)+x(i)*yd(i)
            v2 = x(i)*y(i)
            xd(i) = v1d+v2d
            x(i) = v1+v2
            v1d = v2*v1d+v1*v2d
            v1 = v1*v2
            yd(i) = v2*v1d+v1*v2d
            y(i) = v1*v2
            yd(i) = x(i)*yd(i)+y(i)*xd(i)
            y(i) = y(i)*x(i)
        end do
    end subroutine lh022_jvp

    subroutine lh022_vjp(x, y, xb, yb)
        real(dp), intent(inout) :: x(100), y(100)
        real(dp), intent(inout) :: xb(100), yb(100)
        real(dp) :: x0, y0, xnew, v1, v2, q, r, xbar, ybar
        real(dp) :: v1bar, v2bar, qbar, rbar
        integer :: i

        do i = 100, 1, -1
            x0 = x(i)
            y0 = y(i)
            v1 = (x0+y0)/2.0_dp
            v2 = x0*y0
            xnew = v1+v2
            q = v1*v2
            r = q*v2
            xbar = xb(i)
            ybar = yb(i)
            rbar = ybar*xnew
            xbar = xbar+ybar*r
            qbar = rbar*v2
            v2bar = rbar*q
            v1bar = qbar*v2
            v2bar = v2bar+qbar*v1
            v1bar = v1bar+xbar
            v2bar = v2bar+xbar
            xb(i) = v2bar*y0+v1bar/2.0_dp
            yb(i) = v2bar*x0+v1bar/2.0_dp
        end do
    end subroutine lh022_vjp

    subroutine lh028_primal(a, b)
        real(dp), intent(inout) :: a(100), b(100)
        integer :: i

        do i = 1, 100
            if (a(i) > 0.0_dp) then
                a(i) = a(i)*b(i)
                if (b(i) > 0.0_dp) then
                    b(i) = b(i)+1.0_dp
                else
                    b(i) = b(i)+2.0_dp
                end if
            end if
        end do
    end subroutine lh028_primal

    subroutine lh028_jvp(a, ad, b, bd)
        real(dp), intent(inout) :: a(100), ad(100), b(100), bd(100)
        integer :: i

        do i = 1, 100
            if (a(i) > 0.0_dp) then
                ad(i) = b(i)*ad(i)+a(i)*bd(i)
                a(i) = a(i)*b(i)
                if (b(i) > 0.0_dp) then
                    b(i) = b(i)+1.0_dp
                else
                    b(i) = b(i)+2.0_dp
                end if
            end if
        end do
    end subroutine lh028_jvp

    subroutine lh028_vjp(a, b, ab, bb)
        real(dp), intent(inout) :: a(100), b(100), ab(100), bb(100)
        real(dp) :: a0, b0, a_bar, b_bar
        integer :: i

        do i = 1, 100
            a0 = a(i)
            b0 = b(i)
            a_bar = ab(i)
            b_bar = bb(i)
            if (a0 > 0.0_dp) then
                ab(i) = b0*a_bar
                bb(i) = a0*a_bar+b_bar
            else
                ab(i) = a_bar
                bb(i) = b_bar
            end if
        end do
    end subroutine lh028_vjp
end module tapenade_set01_tranche_l_hand
