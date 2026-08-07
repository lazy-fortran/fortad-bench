subroutine set01_lh064(t, n)
  use iso_fortran_env, only: real64
  implicit none

  real(real64), intent(inout) :: t(0:1000)
  integer, intent(in) :: n
  integer :: i

  ! Bounded, standard-conforming form of cg02v1.  The upstream FORMAT
  ! statements are unreachable and have no observable effect; TRUC is
  ! inlined because its complete body is present in the same source row.
  do i = 1, n
    t(i) = t(i) * 8.0_real64
    if (t(i) > 0.0_real64) then
      t(i) = 0.0_real64
    else
      t(i) = 2.0_real64 * t(i)
      t(i) = 5.0_real64 + t(i)**2
    end if
  end do
end subroutine set01_lh064
