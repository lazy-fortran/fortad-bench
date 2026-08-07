! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh023/program.f at e59864c.
! The computation is unchanged; names, intents, and real64 kinds are explicit.
subroutine set01_lh023(a, b, c)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a, b
    real(dp), intent(out) :: c
    real(dp) :: d

    d = a/100.0_dp
    c = b*b + d
end subroutine set01_lh023
