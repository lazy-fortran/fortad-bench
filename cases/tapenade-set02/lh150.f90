! SPDX-License-Identifier: MIT
! Bounded modern port of Tapenade nonRegressions/set02/lh150.
!
! The upstream regression exercises checkpointing around three calls and
! leaves two local arguments undefined.  This port retains the scalar foo /
! gee computation while exposing the final iterate as an ordinary result.
module tapenade_set02_lh150
  use iso_fortran_env, only : dp => real64
  implicit none
contains
  subroutine set02_lh150(x, y)
    real(dp), intent(in) :: x
    real(dp), intent(out) :: y
    real(dp) :: lc, ld

    lc = 0.0_dp
    ld = 0.0_dp
    y = x
    call foo(y, lc)
    lc = lc + y
    call gee(y, ld)
  end subroutine set02_lh150

  subroutine foo(a, lc)
    real(dp), intent(inout) :: a
    real(dp), intent(inout) :: lc

    a = cos(a * a + lc)
    lc = 2.0_dp * a
  end subroutine foo

  subroutine gee(a, ld)
    real(dp), intent(inout) :: a
    real(dp), intent(inout) :: ld

    a = 2.0_dp * a
    ld = ld + a
  end subroutine gee
end module tapenade_set02_lh150
