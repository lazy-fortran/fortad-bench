! Independent derivative oracle for tapenade_set05_v060.
! SPDX-License-Identifier: MIT
module tapenade_set05_v060_hand
  implicit none
contains
  pure real function func_hand(t, u) result(value)
    real, intent(in) :: t, u
    value = (t + u) / 2.0
  end function func_hand

  pure real function func_jvp_hand(t_d, u_d) result(value_d)
    real, intent(in) :: t_d, u_d
    value_d = (t_d + u_d) / 2.0
  end function func_jvp_hand

  pure subroutine func_vjp_hand(seed, t_b, u_b)
    real, intent(in) :: seed
    real, intent(out) :: t_b, u_b
    t_b = seed / 2.0
    u_b = seed / 2.0
  end subroutine func_vjp_hand
end module tapenade_set05_v060_hand
