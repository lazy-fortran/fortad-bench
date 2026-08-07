! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of Tapenade
! nonRegressions/set01/lh020/program.f.
module tapenade_set01_lh020_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh020(x, y, n, x1_out, branch)
        real(dp), intent(in) :: x(:), y(:)
        real(dp), intent(out) :: x1_out
        integer, intent(in) :: n
        integer, intent(out) :: branch

        x1_out = x(1)
        branch = 0
        if (n > 0) then
            x1_out = x1_out*y(1)
            branch = 1
        end if
    end subroutine set01_lh020
end module tapenade_set01_lh020_case
