! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh074/program.f at e59864c.
subroutine set01_lh074(a, b, chem)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a, b
    real(dp), intent(inout) :: chem(2)
    real(dp) :: w(2)

    w(1) = a*b
    chem(1) = chem(1) - w(1)
    w(2) = a+b
    chem(2) = chem(2) - w(2)
end subroutine set01_lh074
