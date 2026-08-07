module tapenade_set01_lh073_hand
  implicit none
contains

  subroutine hand_jvp(a_in, a_in_d, b_in, b_in_d, a_out, a_out_d, &
      b_out, b_out_d, objective, objective_d)
    real, intent(in) :: a_in(10), a_in_d(10), b_in(10), b_in_d(10)
    real, intent(out) :: a_out(10), a_out_d(10), b_out(10), b_out_d(10)
    real, intent(out) :: objective, objective_d
    integer :: i

    do i = 1, 10
      a_out_d(i) = b_in_d(i) * a_in(i) + b_in(i) * a_in_d(i)
      a_out(i) = b_in(i) * a_in(i)
    end do
    do i = 1, 9
      b_out_d(i) = 2.0 * b_in(i) * b_in_d(i)
      b_out(i) = b_in(i) * b_in(i)
    end do
    b_out_d(10) = 4.0 * b_in(10)**3 * b_in_d(10)
    b_out(10) = b_in(10)**4
    objective_d = sum(a_out_d) + sum(b_out_d)
    objective = sum(a_out) + sum(b_out)
  end subroutine hand_jvp

end module tapenade_set01_lh073_hand
