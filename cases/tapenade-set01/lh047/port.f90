module tapenade_set01_lh047_case
  implicit none
contains

  subroutine set01_lh047(u, z, t, x1, x8, x9, x10, x11, y, v)
    real, intent(inout) :: u, z, t, x1, x8, x9, x10, x11, y, v

    x1 = y * u + t
    u = 0.0
    call sub1_lh047(u, x8, x10, z, v, y)
    t = t + x1 * z + 3.0 * v
    call sub1_lh047(u, x9, x11, z, v, y)
    t = t + x1 * z + 3.0 * u
  end subroutine set01_lh047

  subroutine sub1_lh047(u, y2, y25, z, v, y)
    real, intent(inout) :: u, v, y
    real, intent(in) :: y2, y25, z

    u = u * y + y2 * z
    y = z + v * y
    v = u * y25
  end subroutine sub1_lh047

end module tapenade_set01_lh047_case
