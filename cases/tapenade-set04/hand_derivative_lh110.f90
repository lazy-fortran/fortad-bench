! SPDX-License-Identifier: MIT
module tapenade_set04_lh110_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: set04_lh110_primal, set04_lh110_jvp, set04_lh110_vjp

contains

    subroutine set04_lh110_primal(x, y)
        real(dp), intent(in) :: x
        real(dp), intent(out) :: y

        y = x
    end subroutine set04_lh110_primal

    subroutine set04_lh110_jvp(x, xd, y, yd)
        real(dp), intent(in) :: x, xd
        real(dp), intent(out) :: y, yd

        call set04_lh110_primal(x, y)
        yd = xd
    end subroutine set04_lh110_jvp

    subroutine set04_lh110_vjp(x, y, yb, xb)
        real(dp), intent(in) :: x, y, yb
        real(dp), intent(out) :: xb

        xb = yb
    end subroutine set04_lh110_vjp

end module tapenade_set04_lh110_hand
