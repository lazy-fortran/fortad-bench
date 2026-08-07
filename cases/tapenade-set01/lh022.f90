! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh022/program.f at e59864c.
subroutine set01_lh022(x, y)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: x(100), y(100)
    real(dp) :: v1, v2
    integer :: i

    do i = 1, 100
        v1 = (x(i)+y(i))/2.0_dp
        v2 = x(i)*y(i)
        x(i) = v1+v2
        v1 = v1*v2
        y(i) = v1*v2
        y(i) = y(i)*x(i)
    end do
end subroutine set01_lh022
