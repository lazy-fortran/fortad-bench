! SPDX-License-Identifier: MIT
!
! Independent closed-form JVP/VJP oracle for the bounded lh030 port.  This
! duplicates the mathematics rather than calling the port or generated code.
module tapenade_set01_lh030_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine value_gradient(i1, i2, o, g1, g2)
        real(dp), intent(in) :: i1, i2
        real(dp), intent(out) :: o, g1, g2
        real(dp) :: f1, f2, q1, q2, a, b, da, db, n, d

        f1 = exp(i1*i1)
        f2 = exp(i2*i2)
        q1 = sin(i1)/i1
        q2 = sin(i2)/i2
        a = sqrt(f1 + q1)
        b = sqrt(f2 - q2)
        da = (2.0_dp*i1*f1 + (i1*cos(i1)-sin(i1))/(i1*i1))/(2.0_dp*a)
        db = (2.0_dp*i2*f2 - (i2*cos(i2)-sin(i2))/(i2*i2))/(2.0_dp*b)
        n = a - b
        d = 1.0_dp + a + b
        o = n/d
        g1 = da*(d - n)/(d*d)
        g2 = -db*(d + n)/(d*d)
    end subroutine value_gradient

    subroutine jvp(i1, i2, i1d, i2d, o, od)
        real(dp), intent(in) :: i1, i2, i1d, i2d
        real(dp), intent(out) :: o, od
        real(dp) :: g1, g2

        call value_gradient(i1, i2, o, g1, g2)
        od = g1*i1d + g2*i2d
    end subroutine jvp
end module tapenade_set01_lh030_hand
