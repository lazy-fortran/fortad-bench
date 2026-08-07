module tapenade_set01_v101_hand
  implicit none
contains

  subroutine hand_jvp(x, x_d, y, y_d)
    double precision, intent(in) :: x(2), x_d(2)
    double precision, intent(out) :: y(1), y_d(1)

    y(1) = 4.0d0 * x(1) * x(2)
    y_d(1) = 4.0d0 * (x_d(1) * x(2) + x(1) * x_d(2))
  end subroutine hand_jvp

  subroutine hand_vjp(x, y_b, y, x_b)
    double precision, intent(in) :: x(2), y_b(1)
    double precision, intent(out) :: y(1), x_b(2)

    y(1) = 4.0d0 * x(1) * x(2)
    x_b(1) = 4.0d0 * x(2) * y_b(1)
    x_b(2) = 4.0d0 * x(1) * y_b(1)
  end subroutine hand_vjp

end module tapenade_set01_v101_hand
