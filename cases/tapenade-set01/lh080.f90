! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh080/program.f at e59864c.
subroutine set01_lh080(a, b)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a
    real(dp), intent(out) :: b
    real(dp) :: x(2)

    x(1) = 0.0_dp
    x(2) = a
    x(1) = x(1) + 2.0_dp*a
    b = x(1) + x(2)
end subroutine set01_lh080
