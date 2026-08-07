! Standards-clean scalar port of Tapenade nonRegressions/set05/v052.
! SPDX-License-Identifier: MIT
module tapenade_set05_v052
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure real(dp) function set05_v052(x, i) result(y)
    real(dp), intent(in) :: x
    integer, intent(in) :: i

    y = 2.0_dp*x + 2.0_dp*real(i, dp)
  end function set05_v052

end module tapenade_set05_v052
