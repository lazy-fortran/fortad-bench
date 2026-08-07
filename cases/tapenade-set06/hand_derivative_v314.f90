! Independent oracle for the active computation in set06/v314.
! SPDX-License-Identifier: MIT
module tapenade_set06_v314_hand
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine primal_v314(y, z, x)
    real(dp), intent(in) :: y, z
    real(dp), intent(out) :: x

    x = y + z * z
  end subroutine primal_v314

  pure subroutine jvp_v314(y, z, yd, zd, x, xd)
    real(dp), intent(in) :: y, z, yd, zd
    real(dp), intent(out) :: x, xd

    x = y + z * z
    xd = yd + 2.0_dp * z * zd
  end subroutine jvp_v314

  pure subroutine vjp_v314(y, z, xb, yb, zb)
    real(dp), intent(in) :: y, z, xb
    real(dp), intent(out) :: yb, zb

    yb = xb
    zb = 2.0_dp * z * xb
  end subroutine vjp_v314

end module tapenade_set06_v314_hand
