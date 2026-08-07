! Independent hand JVP/VJP oracle for the bd02 port.
module tapenade_set01_bd02_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: bd02_hand_jvp, bd02_hand_vjp

contains

    subroutine bd02_hand_jvp(b, bd, a, ad)
        real(dp), intent(in) :: b, bd
        real(dp), intent(out) :: a, ad

        a = b
        ad = bd
    end subroutine bd02_hand_jvp

    subroutine bd02_hand_vjp(b, ab, a, a_bar)
        real(dp), intent(in) :: b, a_bar
        real(dp), intent(out) :: ab, a

        a = b
        ab = a_bar
    end subroutine bd02_hand_vjp

end module tapenade_set01_bd02_hand
