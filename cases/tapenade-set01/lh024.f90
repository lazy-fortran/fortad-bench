! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of Tapenade nonRegressions/set01/lh024.
! The temporary yi makes the mutating sub1 call explicit without changing
! the source's update order or the x(15) side effect.
module tapenade_set01_lh024_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh024(x, y)
        real(dp), intent(inout) :: x(100), y(100)
        real(dp) :: v1, v2, yi
        integer :: i

        do i = 1, 100
            v1 = (x(i) + y(i))/2.0_dp
            v2 = x(i)*y(i)
            yi = y(i)
            call set01_lh024_sub1(v1, x, yi)
            y(i) = yi
            x(i) = v1 + v2
            v1 = v1*v2
            y(i) = v1*v2
            y(i) = y(i)*x(i)
        end do
    end subroutine set01_lh024

    subroutine set01_lh024_sub1(v, t, y)
        real(dp), intent(inout) :: v, t(100), y

        v = v*y
        y = y + t(10)*t(20)
        t(15) = v*t(10)
    end subroutine set01_lh024_sub1
end module tapenade_set01_lh024_case
