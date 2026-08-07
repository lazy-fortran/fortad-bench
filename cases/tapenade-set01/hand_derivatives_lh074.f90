! Independent oracle for set01_lh074.
module tapenade_set01_lh074_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh074_jvp(a, ad, b, bd, chem, chemd)
        real(dp), intent(in) :: a, ad, b, bd
        real(dp), intent(inout) :: chem(2), chemd(2)
        chemd(1) = chemd(1) - (b*ad + a*bd)
        chem(1) = chem(1) - a*b
        chemd(2) = chemd(2) - ad - bd
        chem(2) = chem(2) - a - b
    end subroutine lh074_jvp

    subroutine lh074_vjp(a, b, chemb, ab, bb)
        real(dp), intent(in) :: a, b, chemb(2)
        real(dp), intent(out) :: ab, bb
        ab = -b*chemb(1) - chemb(2)
        bb = -a*chemb(1) - chemb(2)
    end subroutine lh074_vjp
end module tapenade_set01_lh074_hand
