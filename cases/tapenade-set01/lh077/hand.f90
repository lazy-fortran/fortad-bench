module tapenade_set01_lh077_hand
  implicit none
contains

  subroutine hand_value(a, b, c, c_out)
    real, intent(in) :: a(100), b, c
    real, intent(out) :: c_out
    real :: l1sq, sum_a_sq
    integer :: i

    l1sq = 0.0
    do i = 1, 100
      l1sq = l1sq + real(1 / i) * real(1 / i)
    end do
    sum_a_sq = 0.0
    do i = 1, 100
      sum_a_sq = sum_a_sq + a(i) * a(i)
    end do
    c_out = 8.5 * ((c + l1sq) * b + sum_a_sq)
  end subroutine hand_value

  subroutine hand_jvp(a, ad, b, bd, c, cd, c_out, c_outd)
    real, intent(in) :: a(100), ad(100), b, bd, c, cd
    real, intent(out) :: c_out, c_outd
    real :: l1sq, sum_a_sq, sum_a_sq_d
    integer :: i

    l1sq = 0.0
    do i = 1, 100
      l1sq = l1sq + real(1 / i) * real(1 / i)
    end do
    sum_a_sq = 0.0
    sum_a_sq_d = 0.0
    do i = 1, 100
      sum_a_sq = sum_a_sq + a(i) * a(i)
      sum_a_sq_d = sum_a_sq_d + 2.0 * a(i) * ad(i)
    end do
    c_out = 8.5 * ((c + l1sq) * b + sum_a_sq)
    c_outd = 8.5 * (cd * b + (c + l1sq) * bd + sum_a_sq_d)
  end subroutine hand_jvp

  subroutine hand_vjp(a, b, c, c_seed, ab, bb, cb)
    real, intent(in) :: a(100), b, c, c_seed
    real, intent(out) :: ab(100), bb, cb
    real :: l1sq
    integer :: i

    l1sq = 0.0
    do i = 1, 100
      l1sq = l1sq + real(1 / i) * real(1 / i)
      ab(i) = c_seed * 17.0 * a(i)
    end do
    bb = c_seed * 8.5 * (c + l1sq)
    cb = c_seed * 8.5 * b
  end subroutine hand_vjp

end module tapenade_set01_lh077_hand
