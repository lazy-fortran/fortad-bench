! Independent hand derivative for the v064 selected value map.
! SPDX-License-Identifier: MIT
module tapenade_set05_v064_hand
  implicit none
contains
  pure double precision function mppsum_real_hand(ptab) result(value)
    double precision, intent(in) :: ptab
    value = ptab + 1.0d0
  end function mppsum_real_hand

  pure subroutine mppsum_real_jvp_hand(ptab, ptab_d, value, value_d)
    double precision, intent(in) :: ptab, ptab_d
    double precision, intent(out) :: value, value_d
    value = ptab + 1.0d0
    value_d = ptab_d
  end subroutine mppsum_real_jvp_hand

  pure subroutine mppsum_real_vjp_hand(ptab, value_b, ptab_b)
    double precision, intent(in) :: ptab, value_b
    double precision, intent(out) :: ptab_b
    ptab_b = value_b
  end subroutine mppsum_real_vjp_hand
end module tapenade_set05_v064_hand
