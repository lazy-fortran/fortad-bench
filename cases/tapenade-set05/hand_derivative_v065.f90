! Independent hand derivative for the v065 selected value map.
! SPDX-License-Identifier: MIT
module tapenade_set05_v065_hand
  implicit none
contains
  pure subroutine mppsum_real2_value_hand(ptab, cst, value)
    double precision, intent(in) :: ptab(10), cst
    double precision, intent(out) :: value(10)
    value = ptab * cst
  end subroutine mppsum_real2_value_hand

  pure subroutine mppsum_real2_value_jvp_hand(ptab, ptab_d, cst, value, value_d)
    double precision, intent(in) :: ptab(10), ptab_d(10), cst
    double precision, intent(out) :: value(10), value_d(10)
    value_d = ptab_d * cst
    value = ptab * cst
  end subroutine mppsum_real2_value_jvp_hand

  pure subroutine mppsum_real2_value_vjp_hand(ptab, cst, value, value_b, ptab_b)
    double precision, intent(in) :: ptab(10), cst, value_b(10)
    double precision, intent(out) :: value(10), ptab_b(10)
    value = ptab * cst
    ptab_b = value_b * cst
  end subroutine mppsum_real2_value_vjp_hand
end module tapenade_set05_v065_hand
