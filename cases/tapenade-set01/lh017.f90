! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh017/program.f at e59864c.
! The implicit branch state is an explicit integer argument, and the
! alternate RETURN is represented by the equivalent IF/ELSE form.
subroutine set01_lh017(a1, a2, branch, b1, b2)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a1, a2
    integer, intent(in) :: branch
    real(dp), intent(out) :: b1, b2
    real(dp) :: x

    x = a1**2
    b2 = 18.0_dp
    b1 = 5.0_dp
    if (branch > 37) then
        x = x*a2
        b1 = x+a1
    else
        b2 = x*a1
    end if
end subroutine set01_lh017
