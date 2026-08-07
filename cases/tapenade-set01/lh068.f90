! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh068/program.f at e59864c.
! HMIN is the original statement function HMIN(CONV)=AMIN1(0., CONV).
! The output split is an oracle-friendly port of the in-place C update.
subroutine set01_lh068_split(a, b, c, c3, c7)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a(:), b(:)
    real(dp), intent(in) :: c(:)
    real(dp), intent(out) :: c3, c7
    real(dp) :: conv
    conv = c(3)*a(1) + b(8)
    c3 = min(0.0_dp, conv)
    conv = c(7)*a(5) + b(12)
    c7 = min(0.0_dp, conv)
end subroutine set01_lh068_split
