! Standards-clean extraction of the exact Tapenade M::func(t,u) closure.
! The unchanged upstream source is compiled and hashed by v062_run.sh.
! SPDX-License-Identifier: MIT
module tapenade_set05_v062
  implicit none
contains
  pure real function func(t, u) result(value)
    real, intent(in) :: t, u
    value = (t + u) / 2.0
  end function func
end module tapenade_set05_v062
