! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh057/program.f at
! e59864cab441d4175df75383b3ff58c3dcd26df9.
! The two in-place results are split into explicit outputs so generated
! reverse signatures have distinct primal and adjoint names.
subroutine set01_lh057_split(a, b, c, a_out, c_out)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a, b, c
    real(dp), intent(out) :: a_out, c_out

    a_out = b*sqrt(a*c)
    c_out = sqrt(a_out*a_out + b*b + c*c)
end subroutine set01_lh057_split
