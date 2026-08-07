! Independent hand JVP/VJP oracle for the bd03 port.
module tapenade_set01_bd03_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: bd03_hand_jvp, bd03_hand_vjp

contains

    subroutine bd03_hand_jvp(b, bd, a, ad)
        real(dp), intent(in) :: b, bd
        real(dp), intent(out) :: a, ad

        a = b
        ad = bd
    end subroutine bd03_hand_jvp

    subroutine bd03_hand_vjp(b, ab, a, a_bar)
        real(dp), intent(in) :: b, a_bar
        real(dp), intent(out) :: ab, a

        a = b
        ab = a_bar
    end subroutine bd03_hand_vjp

end module tapenade_set01_bd03_hand
