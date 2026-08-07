! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of Tapenade
! nonRegressions/set01/lh026/program.f at
! e59864cab441d4175df75383b3ff58c3dcd26df9.
! GOTO 200 restarts the complete sweep after the nonpositive branch.  The
! fixed outer bound and guarded inner loop preserve that control flow without
! a branch into a DO.  The numerical contract stays within max_restarts.
subroutine set01_lh026(a, b)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: a(100), b(100)
    integer :: i, restart_count
    logical :: restart, running

    running = .true.
    do restart_count = 1, 100
        if (running) then
            restart = .false.
            do i = 1, 100
                if (restart .eqv. .false.) then
                    if (a(i) > 0.0_dp) then
                        a(i) = a(i)*b(i)
                        if (b(i) > 0.0_dp) then
                            b(i) = b(i) + 1.0_dp
                        else
                            b(i) = b(i) + 2.0_dp
                            restart = .true.
                        end if
                    end if
                end if
            end do
            running = restart
        end if
    end do
end subroutine set01_lh026
