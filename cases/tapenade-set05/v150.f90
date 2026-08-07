! Standards-clean port of Tapenade nonRegressions/set05/v150.
! SPDX-License-Identifier: MIT
module tapenade_set05_v150
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine set05_v150(t, f)
    real(dp), intent(in) :: t
    real(dp), intent(out) :: f

    f = exp(t * t)
  end subroutine set05_v150

end module tapenade_set05_v150
