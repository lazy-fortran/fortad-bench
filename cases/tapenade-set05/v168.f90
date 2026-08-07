! Standards-clean port of the active map in Tapenade nonRegressions/set05/v168.
! The overwritten intermediate x is represented by local temporaries.
! SPDX-License-Identifier: MIT
module tapenade_set05_v168
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine set05_v168(x, y)
    real(dp), intent(in) :: x(4)
    real(dp), intent(out) :: y(4)
    real(dp) :: u(4)

    u = abs(x * 2.0_dp)
    y = abs(u - 4.0_dp) * u
  end subroutine set05_v168

end module tapenade_set05_v168
