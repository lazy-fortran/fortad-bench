! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh004/program.f at e59864c.
! The original routine accumulates ABS(z) and y until x(1) exceeds y or
! one hundred iterations have run.  This port keeps that loop and exposes
! the two final array entries as useful results.
subroutine set01_lh004(y_initial, z_initial, x1_final, x2_final)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: y_initial, z_initial
    real(dp), intent(out) :: x1_final, x2_final
    real(dp) :: x(2), y, z
    integer :: iter

    y = y_initial
    z = z_initial
    x(1) = 0.0_dp
    x(2) = 0.0_dp
    ! The source's conditional backward jump is equivalent to this bounded
    ! loop: the guard retains the original stopping point while avoiding a
    ! non-structured GOTO in the differentiated port.
    do iter = 1, 101
        if (x(1) <= y) then
            x(1) = x(1) + abs(z)
            x(2) = x(2) + y
        end if
    end do
    x1_final = x(1)
    x2_final = x(2)
end subroutine set01_lh004
