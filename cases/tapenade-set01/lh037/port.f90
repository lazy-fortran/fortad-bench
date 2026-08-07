module tapenade_set01_lh037_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: set01_lh037

contains

    subroutine set01_lh037(a0, b0, c0, a, b, c)
        real(dp), intent(in) :: a0, b0, c0
        real(dp), intent(out) :: a, b, c
        real(dp) :: a1, a2, b1

        ! Straight-line specialization of the exact terminating path.
        ! The caller must satisfy b-c > 8 before entry.
        a1 = a0 + b0
        b1 = b0 - c0
        c = 2.0_dp*a1*b1
        a2 = a1 + 25.5_dp
        c = 2.0_dp*a2*b1
        a = 8.0_dp*a2
        b = b1
    end subroutine set01_lh037

end module tapenade_set01_lh037_case
