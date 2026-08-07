! Standards-clean port of the active computation in Tapenade set06/v314.
! The upstream eor table is inert in the differentiated routine.
! SPDX-License-Identifier: MIT
module tapenade_set06_v314
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine set06_v314(x, y, z)
    real(dp), intent(out) :: x
    real(dp), intent(in) :: y, z

    x = y + z * z
  end subroutine set06_v314

end module tapenade_set06_v314
