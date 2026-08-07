! SPDX-License-Identifier: MIT
! Bounded modern port of Tapenade nonRegressions/set01/lh018/program.f.
module tapenade_set01_lh018_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh018(b, c, a_out)
        real(dp), intent(in) :: b, c(20)
        real(dp), intent(out) :: a_out
        real(dp) :: x, y, z

        a_out = f18(b*c(10), 4.5_dp)
        y = 3.5_dp
        z = 4.5_dp
        x = f18(8.0_dp*y, z)
        a_out = a_out*x
    end subroutine set01_lh018

    real(dp) function f18(u, v) result(value)
        real(dp), intent(in) :: u, v

        value = u + 2.5_dp*u
    end function f18
end module tapenade_set01_lh018_case
