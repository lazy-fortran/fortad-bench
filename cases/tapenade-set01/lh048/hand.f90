module tapenade_set01_lh048_hand
  implicit none
contains

  subroutine hand_value(u, z, t, v, x, y)
    real, intent(inout) :: u, t, v, x(14), y
    real, intent(in) :: z
    real :: x1

    x1 = y * u + t
    x(1) = x1
    u = x(8) * z
    y = z + v * y
    v = u * x(10)
    t = t + x1 * z + 3.0 * v
    y = 0.0
    u = x(9) * z
    y = z
    v = u * x(11)
    t = t + x1 * z + 3.0 * u
  end subroutine hand_value

end module tapenade_set01_lh048_hand
