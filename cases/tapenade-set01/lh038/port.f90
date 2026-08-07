module tapenade_set01_lh038_case
  implicit none
contains

  subroutine set01_lh038(pi, x)
    real, intent(in) :: pi
    real, intent(inout) :: x
    real :: y

    if (x > 20.0) then
      x = 2.0
      y = 5.3
      call f1(x, y, pi)
      x = x + y
    end if
  end subroutine set01_lh038

  subroutine f1(x, y, pi)
    real, intent(in) :: x, pi
    real, intent(inout) :: y

    y = y + 2.0 * x + pi
  end subroutine f1

end module tapenade_set01_lh038_case
