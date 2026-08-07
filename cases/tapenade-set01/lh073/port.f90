module tapenade_set01_lh073_case
  implicit none
contains

  subroutine set01_lh073(a_in, b_in, a_out, b_out, objective)
    real, intent(in) :: a_in(10), b_in(10)
    real, intent(out) :: a_out(10), b_out(10)
    real, intent(out) :: objective
    integer :: i
    real :: z

    do i = 1, 10
      a_out(i) = b_in(i) * a_in(i)
    end do
    do i = 1, 9
      b_out(i) = b_in(i) * b_in(i)
    end do
    z = 8.0
    z = z * z
    b_out(10) = b_in(10) * b_in(10) * b_in(10) * b_in(10)
    objective = sum(a_out) + sum(b_out)
  end subroutine set01_lh073

end module tapenade_set01_lh073_case
