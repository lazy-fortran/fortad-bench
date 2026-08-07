! Standards-clean module extraction of Tapenade nonRegressions/set05/v060.
! SPDX-License-Identifier: MIT
module tapenade_set05_v060
  implicit none
contains
  pure real function func(t, u) result(value)
    real, intent(in) :: t, u
    value = (t + u) / 2.0
  end function func
end module tapenade_set05_v060
