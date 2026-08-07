! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of Tapenade
! nonRegressions/set01/lh031/program.f at
! e59864cab441d4175df75383b3ff58c3dcd26df9.
! The port exposes the three overwritten arguments as explicit outputs so
! independent JVP/VJP checks have a pure input/output boundary.
module tapenade_set01_lh031_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh031(x, y, z, x_out, y_out, z_out)
        real(dp), intent(in) :: x, y, z
        real(dp), intent(out) :: x_out, y_out, z_out
        real(dp) :: x_work, y_work, z_work

        x_work = x + sin(x) - y
        y_work = y*x_work
        z_work = z + x_work*y_work
        x_out = x_work
        y_out = y_work
        z_out = z_work
    end subroutine set01_lh031
end module tapenade_set01_lh031_case
