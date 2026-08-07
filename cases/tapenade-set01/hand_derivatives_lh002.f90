! Independent hand JVP/VJP oracle for the lh002 port.
module tapenade_set01_lh002_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh002_hand_jvp, lh002_hand_vjp

contains

    subroutine lh002_hand_jvp(x_initial, x_initial_d, z_initial, z_initial_d, &
        b_initial, b_initial_d, x_final, x_final_d, y_final, y_final_d, &
        z_final, z_final_d, a_final, a_final_d)
        real(dp), intent(in) :: x_initial, x_initial_d, z_initial, z_initial_d
        real(dp), intent(in) :: b_initial, b_initial_d
        real(dp), intent(out) :: x_final, x_final_d, y_final, y_final_d
        real(dp), intent(out) :: z_final, z_final_d, a_final, a_final_d

        if (x_initial > 0.0_dp) then
            x_final = 1.7_dp + 5.1_dp*z_initial
            x_final_d = 5.1_dp*z_initial_d
            y_final = 1.7_dp
            y_final_d = 0.0_dp
            z_final = 5.1_dp*z_initial
            z_final_d = 5.1_dp*z_initial_d
        else
            x_final = x_initial
            x_final_d = x_initial_d
            y_final = 3.3_dp*x_initial**2
            y_final_d = 6.6_dp*x_initial*x_initial_d
            z_final = z_initial
            z_final_d = z_initial_d
        end if
        a_final = 3.7_dp*b_initial
        a_final_d = 3.7_dp*b_initial_d
    end subroutine lh002_hand_jvp

    subroutine lh002_hand_vjp(x_initial, z_initial, b_initial, x_final_b, &
        y_final_b, z_final_b, a_final_b, x_final, y_final, z_final, a_final, &
        x_initial_b, z_initial_b, b_initial_b)
        real(dp), intent(in) :: x_initial, z_initial, b_initial
        real(dp), intent(in) :: x_final_b, y_final_b, z_final_b, a_final_b
        real(dp), intent(out) :: x_final, y_final, z_final, a_final
        real(dp), intent(out) :: x_initial_b, z_initial_b, b_initial_b

        x_initial_b = 0.0_dp
        z_initial_b = 0.0_dp
        b_initial_b = 3.7_dp*a_final_b
        if (x_initial > 0.0_dp) then
            x_final = 1.7_dp + 5.1_dp*z_initial
            y_final = 1.7_dp
            z_final = 5.1_dp*z_initial
            a_final = 3.7_dp*b_initial
            z_initial_b = 5.1_dp*(x_final_b + z_final_b)
        else
            x_final = x_initial
            y_final = 3.3_dp*x_initial**2
            z_final = z_initial
            a_final = 3.7_dp*b_initial
            x_initial_b = x_final_b + 6.6_dp*x_initial*y_final_b
            z_initial_b = z_final_b
        end if
    end subroutine lh002_hand_vjp

end module tapenade_set01_lh002_hand
