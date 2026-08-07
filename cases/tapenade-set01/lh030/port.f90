! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of
! nonRegressions/set01/lh030/program.f.  The original COMMON block is
! represented by local temporaries because its only role in this case is to
! carry zn and zd from sub0 to head.
module tapenade_set01_lh030_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh030(i1, i2, o)
        real(dp), intent(in) :: i1, i2
        real(dp), intent(out) :: o
        real(dp) :: z1, z2, zn, zd

        z1 = sqrt(f_lh030(i1) + g_lh030(i1))
        z2 = sqrt(f_lh030(i2) - g_lh030(i2))
        zn = z1 - z2
        zd = 1.0_dp + z1 + z2
        o = zn / zd
    end subroutine set01_lh030

    subroutine sub0_lh030(u, v, zn, zd)
        real(dp), intent(in) :: u, v
        real(dp), intent(out) :: zn, zd
        real(dp) :: z1, z2

        call sub1_lh030(u, z1)
        call sub2_lh030(v, z2)
        zn = z1 - z2
        zd = 1.0_dp + z1 + z2
    end subroutine sub0_lh030

    subroutine sub1_lh030(x, y)
        real(dp), intent(in) :: x
        real(dp), intent(out) :: y

        y = sqrt(f_lh030(x) + g_lh030(x))
    end subroutine sub1_lh030

    subroutine sub2_lh030(x, y)
        real(dp), intent(in) :: x
        real(dp), intent(out) :: y

        y = sqrt(f_lh030(x) - g_lh030(x))
    end subroutine sub2_lh030

    pure real(dp) function f_lh030(t) result(value)
        real(dp), intent(in) :: t

        value = exp(t*t)
    end function f_lh030

    pure real(dp) function g_lh030(t) result(value)
        real(dp), intent(in) :: t

        if (t /= 0.0_dp) then
            value = sin(t) / t
        else
            value = 1.0_dp
        end if
    end function g_lh030
end module tapenade_set01_lh030_case
