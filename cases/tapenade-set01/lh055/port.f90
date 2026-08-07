subroutine set01_lh055(a, b)
  use iso_fortran_env, only: real64
  implicit none
  real(real64), intent(out) :: a
  real(real64), intent(in) :: b

  ! Bounded witness for the unresolved upstream TOTO callback.
  a = b * b + 0.25_real64 * b
end subroutine set01_lh055
