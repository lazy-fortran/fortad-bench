module tapenade_set01_lh038_hand
  implicit none
contains

  real function hand_value(pi, x)
    real, intent(in) :: pi, x

    if (x > 20.0) then
      hand_value = 11.3 + pi
    else
      hand_value = x
    end if
  end function hand_value

  real function hand_jvp(pi, x, pi_d, x_d)
    real, intent(in) :: pi, x, pi_d, x_d

    if (x > 20.0) then
      hand_jvp = pi_d
    else
      hand_jvp = x_d
    end if
  end function hand_jvp

end module tapenade_set01_lh038_hand
