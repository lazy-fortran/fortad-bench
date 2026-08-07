module tapenade_set01_lh047_hand
  implicit none
contains

  subroutine hand_value(u, z, t, x1, x8, x9, x10, x11, y, v)
    real, intent(inout) :: u, z, t, x1, x8, x9, x10, x11, y, v
    x1 = y * u + t
    u = 0.0
    u = u * y + x8 * z
    y = z + v * y
    v = u * x10
    t = t + x1 * z + 3.0 * v
    u = u * y + x9 * z
    y = z + v * y
    v = u * x11
    t = t + x1 * z + 3.0 * u
  end subroutine hand_value

  subroutine hand_jvp(u, du, z, dz, t, dt, x1, dx1, x8, dx8, x9, dx9, &
      x10, dx10, x11, dx11, y, dy, v, dv)
    real, intent(inout) :: u, du, z, dz, t, dt, x1, dx1, x8, dx8, x9, dx9
    real, intent(inout) :: x10, dx10, x11, dx11, y, dy, v, dv
    real :: u0, du0, y0, dy0, v0, dv0, t0, dt0
    real :: u1, du1, y1, dy1, v1, dv1

    x1 = y * u + t
    dx1 = dy * u + y * du + dt
    u = 0.0
    du = 0.0
    u0 = u * y + x8 * z
    du0 = du * y + u * dy + dx8 * z + x8 * dz
    y0 = z + v * y
    dy0 = dz + dv * y + v * dy
    v0 = u0 * x10
    dv0 = du0 * x10 + u0 * dx10
    t0 = t + x1 * z + 3.0 * v0
    dt0 = dt + dx1 * z + x1 * dz + 3.0 * dv0
    u1 = u0 * y0 + x9 * z
    du1 = du0 * y0 + u0 * dy0 + dx9 * z + x9 * dz
    y1 = z + v0 * y0
    dy1 = dz + dv0 * y0 + v0 * dy0
    v1 = u1 * x11
    dv1 = du1 * x11 + u1 * dx11
    t = t0 + x1 * z + 3.0 * u1
    dt = dt0 + dx1 * z + x1 * dz + 3.0 * du1
    u = u1
    du = du1
    y = y1
    dy = dy1
    v = v1
    dv = dv1
  end subroutine hand_jvp

end module tapenade_set01_lh047_hand
