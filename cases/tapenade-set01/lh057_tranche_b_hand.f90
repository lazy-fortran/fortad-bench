! Independent oracle for the split-output lh057 port.
module tapenade_set01_lh057_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh057_hand_jvp, lh057_hand_vjp_a, lh057_hand_vjp_c

contains

    subroutine lh057_hand_jvp(a, a_d, b, b_d, c, c_d, a_out, a_out_d, &
        c_out, c_out_d)
        real(dp), intent(in) :: a, a_d, b, b_d, c, c_d
        real(dp), intent(out) :: a_out, a_out_d, c_out, c_out_d
        real(dp) :: root_a

        root_a = sqrt(a*c)
        a_out = b*root_a
        a_out_d = b_d*root_a + b*(a_d*c + a*c_d)/(2.0_dp*root_a)
        c_out = sqrt(a_out*a_out + b*b + c*c)
        c_out_d = (a_out*a_out_d + b*b_d + c*c_d)/c_out
    end subroutine lh057_hand_jvp

    subroutine lh057_hand_vjp_a(a, b, c, a_out_b, a_b, b_b, c_b)
        real(dp), intent(in) :: a, b, c, a_out_b
        real(dp), intent(out) :: a_b, b_b, c_b
        real(dp) :: root_a

        root_a = sqrt(a*c)
        a_b = a_out_b*b*c/(2.0_dp*root_a)
        b_b = a_out_b*root_a
        c_b = a_out_b*b*a/(2.0_dp*root_a)
    end subroutine lh057_hand_vjp_a

    subroutine lh057_hand_vjp_c(a, b, c, c_out_b, a_b, b_b, c_b)
        real(dp), intent(in) :: a, b, c, c_out_b
        real(dp), intent(out) :: a_b, b_b, c_b
        real(dp) :: root_a, a_out, c_out, a_out_b

        root_a = sqrt(a*c)
        a_out = b*root_a
        c_out = sqrt(a_out*a_out + b*b + c*c)
        a_out_b = c_out_b*a_out/c_out
        a_b = a_out_b*b*c/(2.0_dp*root_a)
        b_b = c_out_b*b/c_out + a_out_b*root_a
        c_b = c_out_b*c/c_out + a_out_b*b*a/(2.0_dp*root_a)
    end subroutine lh057_hand_vjp_c

end module tapenade_set01_lh057_hand
