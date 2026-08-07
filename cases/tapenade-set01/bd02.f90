! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/bd02/program.f at e59864c.
! The nested assignment call is retained.
subroutine set01_bd02(b, a)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: b
    real(dp), intent(out) :: a

    call set01_bd02_titi(a, b)
end subroutine set01_bd02

subroutine set01_bd02_titi(a, b)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(out) :: a
    real(dp), intent(in) :: b

    a = b
end subroutine set01_bd02_titi
