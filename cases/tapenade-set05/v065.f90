! Standards-clean value-map extraction of one exact Tapenade
! nonRegressions/set05/v065 mppsum_real2 loop.
! The unchanged upstream source and stored references are compiled and hashed
! by v065_run.sh. This is not a repaired upstream source.
! SPDX-License-Identifier: MIT
module tapenade_set05_v065
  implicit none
contains
  pure subroutine mppsum_real2_value(ptab, cst, value)
    double precision, intent(in) :: ptab(10), cst
    double precision, intent(out) :: value(10)
    value = ptab * cst
  end subroutine mppsum_real2_value
end module tapenade_set05_v065
