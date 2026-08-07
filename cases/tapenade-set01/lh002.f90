! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh002/program.f at e59864c.
! The original top routine updates x, y, z, and a in place and calls sub1
! twice.  This port exposes the final state as outputs while retaining the
! branch and call sequencing.  The initial x, z, and b are independent.
subroutine set01_lh002(x_initial, z_initial, b_initial, x_final, y_final, &
    z_final, a_final)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x_initial, z_initial, b_initial
    real(dp), intent(out) :: x_final, y_final, z_final, a_final
    real(dp) :: x, y, z, a, b, c

    x = x_initial
    z = z_initial
    b = b_initial
    c = 0.0_dp
    if (x > 0.0_dp) then
        y = 1.7_dp
        call set01_lh002_sub1(x, y, z)
        z = 5.1_dp*z
        x = y + z
    else
        y = 3.3_dp*x**2
    end if
    a = -2.9_dp
    call set01_lh002_sub1(a, b, c)
    x_final = x
    y_final = y
    z_final = z
    a_final = a
end subroutine set01_lh002

subroutine set01_lh002_sub1(x, y, z)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: x
    real(dp), intent(in) :: y
    real(dp), intent(inout) :: z

    x = 3.7_dp*y
end subroutine set01_lh002_sub1
