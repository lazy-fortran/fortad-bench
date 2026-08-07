module tapenade_set01_lh070_case
  implicit none
contains

  subroutine set01_lh070(a, b, x, y, z)
    real, intent(inout) :: a(10), b(10), x, y, z

    a(1) = 2.0 * a(2) + x
    call f_lh070(x, y, z)
    b(1) = 2.0 * b(2) + y
  end subroutine set01_lh070

  subroutine f_lh070(x, y, z)
    real, intent(inout) :: x, y
    real, intent(in) :: z

    y = x * z
    x = 3.0
  end subroutine f_lh070

end module tapenade_set01_lh070_case
