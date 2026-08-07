module lh064_hand_mod
  use iso_fortran_env, only: real64
  implicit none
  private
  public :: set01_lh064_hand

contains

  subroutine set01_lh064_hand(t, td, n)
    real(real64), intent(inout) :: t(0:1000)
    real(real64), intent(inout) :: td(0:1000)
    integer, intent(in) :: n
    integer :: i
    real(real64) :: x

    do i = 1, n
      x = t(i)
      if (8.0_real64 * x > 0.0_real64) then
        t(i) = 0.0_real64
        td(i) = 0.0_real64
      else
        t(i) = 5.0_real64 + 256.0_real64 * x**2
        td(i) = 512.0_real64 * x * td(i)
      end if
    end do
  end subroutine set01_lh064_hand

end module lh064_hand_mod
