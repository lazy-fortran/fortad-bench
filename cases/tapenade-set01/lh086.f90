! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Bounded port of Tapenade nonRegressions/set01/lh086/program.f at
! e59864c. The upstream routine updates x in place; y makes that final
! iterate an explicit dependent so both FortAD modes have a valid interface.
subroutine set01_lh086(x, n, alpha, y)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x
    integer, intent(in) :: n
    real(dp), intent(in) :: alpha
    real(dp), intent(out) :: y
    integer :: i
    real(dp) :: f, fp

    y = x
    do i = 1, n
        f = y - alpha*cos(y)
        fp = 1.0_dp + alpha*sin(y)
        y = y - f/fp
    end do
end subroutine set01_lh086
