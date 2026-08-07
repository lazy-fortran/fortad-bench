! Independent oracle for the scalar set05/v052 map.
! SPDX-License-Identifier: MIT
module tapenade_set05_v052_hand
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure real(dp) function primal_v052(x, i) result(y)
    real(dp), intent(in) :: x
    integer, intent(in) :: i

    y = 2.0_dp*x + 2.0_dp*real(i, dp)
  end function primal_v052

  pure real(dp) function jvp_v052(x, i, xd) result(yd)
    real(dp), intent(in) :: x, xd
    integer, intent(in) :: i

    ! The integer input is intentionally absent from the tangent map.
    yd = 2.0_dp*xd
  end function jvp_v052

  pure real(dp) function vjp_v052(x, i, yb) result(xb)
    real(dp), intent(in) :: x, yb
    integer, intent(in) :: i

    ! The integer input has no real adjoint.
    xb = 2.0_dp*yb
  end function vjp_v052

end module tapenade_set05_v052_hand
