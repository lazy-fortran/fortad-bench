! Standards-clean callable port of Tapenade nonRegressions/set06/v379.
! SPDX-License-Identifier: MIT
module tapenade_set06_v379
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine set06_v379(n, x, f)
    integer, intent(in) :: n
    real(dp), intent(in) :: x(max(n, 1))
    real(dp), intent(out) :: f

    f = sqrt(sum(x)**2)
  end subroutine set06_v379

end module tapenade_set06_v379
