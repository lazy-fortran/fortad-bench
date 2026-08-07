module tapenade_set01_lh070_hand
  implicit none
contains

  subroutine hand_value(a, b, x, y, z)
    real, intent(inout) :: a(10), b(10), x, y
    real, intent(in) :: z

    a(1) = 2.0 * a(2) + x
    y = x * z
    x = 3.0
    b(1) = 2.0 * b(2) + y
  end subroutine hand_value

  subroutine hand_jvp(a, ad, b, bd, x, xd, y, yd, z, zd)
    real, intent(inout) :: a(10), ad(10), b(10), bd(10)
    real, intent(inout) :: x, xd, y, yd, z, zd

    ad(1) = 2.0 * ad(2) + xd
    a(1) = 2.0 * a(2) + x
    yd = xd * z + x * zd
    y = x * z
    xd = 0.0
    x = 3.0
    bd(1) = 2.0 * bd(2) + yd
    b(1) = 2.0 * b(2) + y
  end subroutine hand_jvp

end module tapenade_set01_lh070_hand
