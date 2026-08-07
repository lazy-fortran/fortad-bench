! Independent hand oracle for the v054 vector reciprocal map.
! SPDX-License-Identifier: MIT
module tapenade_set05_v054_hand
  implicit none
contains
  pure function primal_v054(x)
    real, intent(in) :: x(:)
    real :: primal_v054(size(x))
    primal_v054 = 1.0 / x
  end function primal_v054
  pure function jvp_v054(x, xd)
    real, intent(in) :: x(:), xd(:)
    real :: jvp_v054(size(x))
    jvp_v054 = -xd / x**2
  end function jvp_v054
  pure function vjp_v054(x, yb)
    real, intent(in) :: x(:), yb(:)
    real :: vjp_v054(size(x))
    vjp_v054 = -yb / x**2
  end function vjp_v054
end module tapenade_set05_v054_hand
