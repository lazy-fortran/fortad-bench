! SPDX-License-Identifier: MIT
module tapenade_set02_lh150_hand
  use iso_fortran_env, only : dp => real64
  implicit none
contains
  subroutine primal_lh150(x, y)
    real(dp), intent(in) :: x
    real(dp), intent(out) :: y

    y = 2.0_dp * cos(x * x)
  end subroutine primal_lh150

  subroutine jvp_lh150(x, dx, y, dy)
    real(dp), intent(in) :: x, dx
    real(dp), intent(out) :: y, dy

    y = 2.0_dp * cos(x * x)
    dy = -4.0_dp * x * sin(x * x) * dx
  end subroutine jvp_lh150

  subroutine vjp_lh150(x, yb, xb)
    real(dp), intent(in) :: x, yb
    real(dp), intent(out) :: xb

    xb = -4.0_dp * x * sin(x * x) * yb
  end subroutine vjp_lh150
end module tapenade_set02_lh150_hand
