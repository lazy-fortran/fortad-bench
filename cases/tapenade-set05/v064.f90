! Standards-clean value-map extraction of the exact Tapenade
! nonRegressions/set05/v064 mppsum_real inout assignment.
! The unchanged upstream source is compiled and hashed by v064_run.sh.
! This is not a repaired upstream source.
! SPDX-License-Identifier: MIT
module tapenade_set05_v064
  implicit none
contains
  pure double precision function mppsum_real(ptab) result(value)
    double precision, intent(in) :: ptab
    value = ptab + 1.0d0
  end function mppsum_real
end module tapenade_set05_v064
