module tapenade_set01_hand_derivatives
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: lh023_hand_jvp, lh023_hand_vjp
    public :: lh032_hand_jvp, lh032_hand_vjp
    public :: lh134_hand_jvp, lh134_hand_vjp

contains

    subroutine lh023_hand_jvp(a, a_d, b, b_d, c, c_d)
        real(dp), intent(in) :: a, a_d, b, b_d
        real(dp), intent(out) :: c, c_d

        c = b*b + a/100.0_dp
        c_d = 2.0_dp*b*b_d + a_d/100.0_dp
    end subroutine lh023_hand_jvp

    subroutine lh023_hand_vjp(a, b, c_b, c, a_b, b_b)
        real(dp), intent(in) :: a, b, c_b
        real(dp), intent(out) :: c, a_b, b_b

        c = b*b + a/100.0_dp
        a_b = c_b/100.0_dp
        b_b = 2.0_dp*b*c_b
    end subroutine lh023_hand_vjp

    subroutine lh032_hand_jvp(x, x_d, y, y_d)
        real(dp), intent(in) :: x, x_d
        real(dp), intent(out) :: y, y_d

        y = 2.0_dp*x*x
        y_d = 4.0_dp*x*x_d
    end subroutine lh032_hand_jvp

    subroutine lh032_hand_vjp(x, y_b, y, x_b)
        real(dp), intent(in) :: x, y_b
        real(dp), intent(out) :: y, x_b

        y = 2.0_dp*x*x
        x_b = 4.0_dp*x*y_b
    end subroutine lh032_hand_vjp

    subroutine lh134_hand_jvp(x, x_d, f, f_d)
        real(dp), intent(in) :: x, x_d
        real(dp), intent(out) :: f, f_d

        f = log(-x)
        f_d = x_d/x
    end subroutine lh134_hand_jvp

    subroutine lh134_hand_vjp(x, f_b, f, x_b)
        real(dp), intent(in) :: x, f_b
        real(dp), intent(out) :: f, x_b

        f = log(-x)
        x_b = f_b/x
    end subroutine lh134_hand_vjp

end module tapenade_set01_hand_derivatives
