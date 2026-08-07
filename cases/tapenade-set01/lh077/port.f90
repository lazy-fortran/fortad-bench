module tapenade_set01_lh077_case
  implicit none
contains

  subroutine set01_lh077(a, b, c, c_out)
    real, intent(in) :: a(100), b, c
    real, intent(out) :: c_out
    c_out = 8.5 * ((c + 1.0) * b + sum(a * a))
  end subroutine set01_lh077

end module tapenade_set01_lh077_case
