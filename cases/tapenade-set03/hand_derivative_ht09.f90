module tapenade_set03_ht09_hand
  implicit none
contains
  subroutine primal_ht09(x, y)
    real, intent(in) :: x(10)
    real, intent(out) :: y(10)

    y = sqrt(abs(x))
  end subroutine primal_ht09

  subroutine jvp_ht09(x, xd, yd)
    real, intent(in) :: x(10), xd(10)
    real, intent(out) :: yd(10)

    yd = sign(1.0, x) * xd / (2.0 * sqrt(abs(x)))
  end subroutine jvp_ht09

  subroutine vjp_ht09(x, yb, xb)
    real, intent(in) :: x(10), yb(10)
    real, intent(out) :: xb(10)

    xb = yb * sign(1.0, x) / (2.0 * sqrt(abs(x)))
  end subroutine vjp_ht09
end module tapenade_set03_ht09_hand
