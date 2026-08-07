! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh028/program.f at e59864c.
subroutine set01_lh028(a, b)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: a(100), b(100)
    integer :: i

    do i = 1, 100
        if (a(i) > 0.0_dp) then
            a(i) = a(i)*b(i)
            if (b(i) > 0.0_dp) then
                b(i) = b(i)+1.0_dp
            else
                b(i) = b(i)+2.0_dp
            end if
        end if
    end do
end subroutine set01_lh028
