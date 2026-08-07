! Independent oracle for set05/v150.
! SPDX-License-Identifier: MIT
module tapenade_set05_v150_hand
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine primal_v150(t, f)
    real(dp), intent(in) :: t
    real(dp), intent(out) :: f

    f = exp(t * t)
  end subroutine primal_v150

  pure subroutine jvp_v150(t, td, f, fd)
    real(dp), intent(in) :: t, td
    real(dp), intent(out) :: f, fd

    f = exp(t * t)
    fd = 2.0_dp * t * f * td
  end subroutine jvp_v150

  pure subroutine vjp_v150(t, fb, tb)
    real(dp), intent(in) :: t, fb
    real(dp), intent(out) :: tb

    tb = 2.0_dp * t * exp(t * t) * fb
  end subroutine vjp_v150

end module tapenade_set05_v150_hand
