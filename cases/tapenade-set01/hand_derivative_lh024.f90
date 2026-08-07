! SPDX-License-Identifier: MIT
!
! Independent forward and reverse oracle for the bounded lh024 port.  The
! reverse routine uses explicit per-iteration state snapshots; it is not
! derived from FortAD output and intentionally supplies the storage that the
! exact FortAD reverse transform reports as missing.
module tapenade_set01_lh024_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh024_hand_jvp(x, y, xd, yd, x_out, y_out, xd_out, yd_out)
        real(dp), intent(in) :: x(100), y(100), xd(100), yd(100)
        real(dp), intent(out) :: x_out(100), y_out(100)
        real(dp), intent(out) :: xd_out(100), yd_out(100)
        real(dp) :: v1, v1d, v2, v2d, yi, yid
        integer :: i

        x_out = x
        y_out = y
        xd_out = xd
        yd_out = yd
        do i = 1, 100
            v1d = (xd_out(i) + yd_out(i))/2.0_dp
            v1 = (x_out(i) + y_out(i))/2.0_dp
            v2d = x_out(i)*yd_out(i) + y_out(i)*xd_out(i)
            v2 = x_out(i)*y_out(i)
            yi = y_out(i)
            yid = yd_out(i)
            v1d = v1d*yi + v1*yid
            v1 = v1*yi
            yid = yid + x_out(20)*xd_out(10) + x_out(10)*xd_out(20)
            yi = yi + x_out(10)*x_out(20)
            xd_out(15) = v1d*x_out(10) + v1*xd_out(10)
            x_out(15) = v1*x_out(10)
            yd_out(i) = yid
            y_out(i) = yi
            xd_out(i) = v1d + v2d
            x_out(i) = v1 + v2
            v1d = v2*v1d + v1*v2d
            v1 = v1*v2
            yd_out(i) = v2*v1d + v1*v2d
            y_out(i) = v1*v2
            yd_out(i) = x_out(i)*yd_out(i) + y_out(i)*xd_out(i)
            y_out(i) = y_out(i)*x_out(i)
        end do
    end subroutine lh024_hand_jvp

    subroutine lh024_hand_vjp(x, y, xb_seed, yb_seed, xb, yb)
        real(dp), intent(in) :: x(100), y(100)
        real(dp), intent(in) :: xb_seed(100), yb_seed(100)
        real(dp), intent(out) :: xb(100), yb(100)
        real(dp), allocatable :: xs(:, :), ys(:, :)
        real(dp) :: v1s(100), v2s(100), yis(100), vs(100)
        real(dp) :: v, v2, q, vbar, v1bar, v2bar, yibar
        real(dp) :: x10, x20, yi0, v1i
        real(dp) :: y_before_last, x_after_assign
        integer :: i

        allocate(xs(101, 100), ys(101, 100))
        xs(1, :) = x
        ys(1, :) = y
        do i = 1, 100
            v1i = (xs(i, i) + ys(i, i))/2.0_dp
            v2 = xs(i, i)*ys(i, i)
            yi0 = ys(i, i)
            x10 = xs(i, 10)
            x20 = xs(i, 20)
            v = v1i*yi0
            vs(i) = v
            v1s(i) = v1i
            v2s(i) = v2
            yis(i) = yi0
            xs(i + 1, :) = xs(i, :)
            ys(i + 1, :) = ys(i, :)
            ys(i + 1, i) = yi0 + x10*x20
            xs(i + 1, 15) = v*x10
            xs(i + 1, i) = v + v2
            v = v*v2
            ys(i + 1, i) = v*v2
            ys(i + 1, i) = ys(i + 1, i)*xs(i + 1, i)
        end do

        xb = xb_seed
        yb = yb_seed
        do i = 100, 1, -1
            v1i = v1s(i)
            v2 = v2s(i)
            yi0 = yis(i)
            v = vs(i)
            x10 = xs(i, 10)
            q = yb(i)
            y_before_last = v*v2*v2
            x_after_assign = v + v2
            xb(i) = xb(i) + q*y_before_last
            q = q*x_after_assign
            yb(i) = 0.0_dp

            vbar = q*v2
            v2bar = q*v*v2
            v1bar = v2*vbar
            v2bar = v2bar + v*vbar
            q = xb(i)
            xb(i) = 0.0_dp
            v1bar = v1bar + q
            v2bar = v2bar + q

            q = xb(15)
            xb(15) = 0.0_dp
            v1bar = v1bar + q*x10
            xb(10) = xb(10) + q*v
            yibar = v1bar*v1i
            v1bar = v1bar*yi0

            xb(i) = xb(i) + v2bar*ys(i, i) + v1bar/2.0_dp
            yb(i) = yb(i) + v2bar*xs(i, i) + yibar + v1bar/2.0_dp
        end do
        deallocate(xs, ys)
    end subroutine lh024_hand_vjp
end module tapenade_set01_lh024_hand
