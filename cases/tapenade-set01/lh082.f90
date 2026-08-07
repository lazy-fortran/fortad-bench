! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Bounded port of Tapenade nonRegressions/set01/lh082/program.f at
! e59864c. The upper bound covers the fixed-index writes for the n=0
! forward probe; reverse mode remains refused for the aliasing loop.
subroutine set01_lh082(a, n, x)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    integer, intent(in) :: n
    real(dp), intent(inout) :: a(1:n+5)
    real(dp), intent(in) :: x
    integer :: i

    a(5) = x*x
    a(4) = 8.0_dp*a(3)
    do i = 1, n
        a(i) = a(i)*a(n-i)
        a(i-1) = 2.0_dp*a(i-1)
        a(i-2) = 3.0_dp*a(i+3)
    end do
end subroutine set01_lh082
