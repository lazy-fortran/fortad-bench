! SPDX-License-Identifier: MIT
! Bounded port of Tapenade nonRegressions/set04/lh110.
!
! The exact regression uses TARGET objects and POINTER links.  This port
! preserves its active storage/dataflow chain while making the storage
! lifetime explicit, which is the boundary currently rejected by FortAD.
subroutine set04_lh110(x, y)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x
    real(dp), intent(out) :: y
    real(dp) :: le1, le2

    le1 = x
    le2 = le1
    y = le2
end subroutine set04_lh110
