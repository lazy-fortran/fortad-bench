! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/bd01/program.f at e59864c.
! The nested function and in-place state updates are retained.
subroutine set01_bd01(x_initial, y_initial, z_initial, w_final, x_final, &
    y_final, z_final)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x_initial, y_initial, z_initial
    real(dp), intent(out) :: w_final, x_final, y_final, z_final
    real(dp) :: w, x, y, z

    x = x_initial
    y = y_initial
    z = z_initial
    call set01_bd01_toto(x, y, z, w)
    x = w*w
    y = x + w*z
    w_final = w
    x_final = x
    y_final = y
    z_final = z
end subroutine set01_bd01

subroutine set01_bd01_toto(x, y, z, toto)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: x, y, z
    real(dp), intent(out) :: toto
    real(dp) :: a

    a = x + y
    toto = x*y*z*a
end subroutine set01_bd01_toto
