module tapenade_set01_lh050_hand
  implicit none
contains

  subroutine hand_value(x, y, z, y_out, z_out)
    real, intent(in) :: x, y, z
    real, intent(out) :: y_out, z_out
    real :: u

    u = x * y
    z_out = z
    if (x > 0.0) then
      z_out = 3.0 * u**2 + x
      u = 2.0
    end if
    y_out = u * x
  end subroutine hand_value

  subroutine hand_jvp(x, y, z, x_d, y_d, z_d, y_out_d, z_out_d)
    real, intent(in) :: x, y, z, x_d, y_d, z_d
    real, intent(out) :: y_out_d, z_out_d
    real :: u, u_d

    u = x * y
    u_d = y * x_d + x * y_d
    z_out_d = z_d
    if (x > 0.0) then
      z_out_d = 6.0 * u * u_d + x_d
      u_d = 0.0
      u = 2.0
    end if
    y_out_d = u_d * x + u * x_d
  end subroutine hand_jvp

  subroutine hand_vjp_z(x, y, z_b, x_b, y_b)
    real, intent(in) :: x, y, z_b
    real, intent(out) :: x_b, y_b

    if (x > 0.0) then
      x_b = z_b * (6.0 * x * y**2 + 1.0)
      y_b = z_b * (6.0 * x**2 * y)
    else
      x_b = 0.0
      y_b = 0.0
    end if
  end subroutine hand_vjp_z

end module tapenade_set01_lh050_hand
