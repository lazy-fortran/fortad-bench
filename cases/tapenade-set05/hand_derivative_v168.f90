! Independent oracle for set05/v168 away from ABS kinks.
! SPDX-License-Identifier: MIT
module tapenade_set05_v168_hand
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine primal_v168(x, y)
    real(dp), intent(in) :: x(4)
    real(dp), intent(out) :: y(4)
    real(dp) :: u(4)

    u = abs(x * 2.0_dp)
    y = abs(u - 4.0_dp) * u
  end subroutine primal_v168

  pure subroutine jvp_v168(x, xd, y, yd)
    real(dp), intent(in) :: x(4), xd(4)
    real(dp), intent(out) :: y(4), yd(4)
    real(dp) :: u(4), ud(4), v, vd
    integer :: i

    u = abs(x * 2.0_dp)
    ud = sign(2.0_dp, x) * xd
    y = abs(u - 4.0_dp) * u
    do i = 1, 4
      v = abs(u(i) - 4.0_dp)
      vd = sign(1.0_dp, u(i) - 4.0_dp) * ud(i)
      yd(i) = vd * u(i) + v * ud(i)
    end do
  end subroutine jvp_v168

  pure subroutine vjp_v168(x, yb, xb)
    real(dp), intent(in) :: x(4), yb(4)
    real(dp), intent(out) :: xb(4)
    real(dp) :: u(4), v, ub
    integer :: i

    u = abs(x * 2.0_dp)
    do i = 1, 4
      v = abs(u(i) - 4.0_dp)
      ub = yb(i) * (v + u(i) * sign(1.0_dp, u(i) - 4.0_dp))
      xb(i) = ub * sign(2.0_dp, x(i))
    end do
  end subroutine vjp_v168

end module tapenade_set05_v168_hand
