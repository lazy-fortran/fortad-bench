module tapenade_set01_lh050_case
  implicit none
contains

  subroutine set01_lh050(x, y, z)
    real, intent(in) :: x
    real, intent(inout) :: y
    real, intent(inout) :: z
    real :: u

    u = x * y
    if (x > 0.0) then
      z = 3.0 * u**2 + x
      u = 2.0
    end if
    y = u * x
  end subroutine set01_lh050

end module tapenade_set01_lh050_case
