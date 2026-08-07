! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh049/program.f at e59864c.
! The in-place y update and useful z output are retained.
subroutine set01_lh049(x, y, z)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x
    real(dp), intent(inout) :: y
    real(dp), intent(out) :: z
    real(dp) :: u

    u = x*y
    z = 3.0_dp*u**2 + x
    u = 2.0_dp
    y = u*x
end subroutine set01_lh049
