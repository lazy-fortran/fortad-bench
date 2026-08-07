! Independent branch-aware JVP/VJP oracle for the lh068 statement function.
module tapenade_set01_lh068_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh068_hand_jvp, lh068_hand_vjp

contains

    subroutine lh068_hand_jvp(a, a_d, b, b_d, c, c_d, c3, c3_d, c7, c7_d)
        real(dp), intent(in) :: a(:), a_d(:), b(:), b_d(:), c(:), c_d(:)
        real(dp), intent(out) :: c3, c3_d, c7, c7_d
        real(dp) :: conv, conv_d
        conv = c(3)*a(1) + b(8)
        conv_d = c_d(3)*a(1) + c(3)*a_d(1) + b_d(8)
        if (conv < 0.0_dp) then
            c3 = conv
            c3_d = conv_d
        else
            c3 = 0.0_dp
            c3_d = 0.0_dp
        end if
        conv = c(7)*a(5) + b(12)
        conv_d = c_d(7)*a(5) + c(7)*a_d(5) + b_d(12)
        if (conv < 0.0_dp) then
            c7 = conv
            c7_d = conv_d
        else
            c7 = 0.0_dp
            c7_d = 0.0_dp
        end if
    end subroutine lh068_hand_jvp

    subroutine lh068_hand_vjp(a, b, c, c3_b, c7_b, a_b, b_b, c_b)
        real(dp), intent(in) :: a(:), b(:), c(:), c3_b, c7_b
        real(dp), intent(out) :: a_b(:), b_b(:), c_b(:)
        real(dp) :: conv
        a_b = 0.0_dp
        b_b = 0.0_dp
        c_b = 0.0_dp
        conv = c(3)*a(1) + b(8)
        if (conv < 0.0_dp) then
            a_b(1) = c(3)*c3_b
            b_b(8) = c3_b
            c_b(3) = a(1)*c3_b
        end if
        conv = c(7)*a(5) + b(12)
        if (conv < 0.0_dp) then
            a_b(5) = a_b(5) + c(7)*c7_b
            b_b(12) = b_b(12) + c7_b
            c_b(7) = c_b(7) + a(5)*c7_b
        end if
    end subroutine lh068_hand_vjp

end module tapenade_set01_lh068_hand
