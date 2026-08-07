! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh134/program.f at e59864c.
! The computation is unchanged; names, intents, and real64 kinds are explicit.
subroutine set01_lh134(x, f)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x
    real(dp), intent(out) :: f

    f = log(-x)
end subroutine set01_lh134
