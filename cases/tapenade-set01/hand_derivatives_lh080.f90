! Independent oracle for set01_lh080.
module tapenade_set01_lh080_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh080_jvp(a, ad, b, bd)
        real(dp), intent(in) :: a, ad
        real(dp), intent(out) :: b, bd
        b = 3.0_dp*a
        bd = 3.0_dp*ad
    end subroutine lh080_jvp

    subroutine lh080_vjp(a, b, bb, ab)
        real(dp), intent(in) :: a, b, bb
        real(dp), intent(out) :: ab
        ab = 3.0_dp*bb
    end subroutine lh080_vjp
end module tapenade_set01_lh080_hand
