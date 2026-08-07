! Independent oracle for set06/v379 away from the zero-sum kink.
! SPDX-License-Identifier: MIT
module tapenade_set06_v379_hand
  use iso_fortran_env, only: dp => real64
  implicit none
contains

  pure subroutine primal_v379(n, x, f)
    integer, intent(in) :: n
    real(dp), intent(in) :: x(max(n, 1))
    real(dp), intent(out) :: f

    f = abs(sum(x))
  end subroutine primal_v379

  pure subroutine jvp_v379(n, x, xd, f, fd)
    integer, intent(in) :: n
    real(dp), intent(in) :: x(max(n, 1)), xd(max(n, 1))
    real(dp), intent(out) :: f, fd
    real(dp) :: total

    total = sum(x)
    f = abs(total)
    fd = sign(1.0_dp, total) * sum(xd)
  end subroutine jvp_v379

  pure subroutine vjp_v379(n, x, fb, xb)
    integer, intent(in) :: n
    real(dp), intent(in) :: x(max(n, 1)), fb
    real(dp), intent(out) :: xb(max(n, 1))

    xb = sign(1.0_dp, sum(x)) * fb
  end subroutine vjp_v379

end module tapenade_set06_v379_hand
