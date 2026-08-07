! Independent hand JVP/VJP oracle for the lh004 port.
module tapenade_set01_lh004_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh004_hand_jvp, lh004_hand_vjp

contains

    subroutine lh004_hand_jvp(y_initial, y_initial_d, z_initial, z_initial_d, &
        x1_final, x1_final_d, x2_final, x2_final_d)
        real(dp), intent(in) :: y_initial, y_initial_d, z_initial, z_initial_d
        real(dp), intent(out) :: x1_final, x1_final_d, x2_final, x2_final_d
        integer :: iterations

        call iteration_count(y_initial, z_initial, iterations)
        x1_final = real(iterations, dp)*abs(z_initial)
        x2_final = real(iterations, dp)*y_initial
        x1_final_d = real(iterations, dp)*sign(1.0_dp, z_initial)*z_initial_d
        x2_final_d = real(iterations, dp)*y_initial_d
    end subroutine lh004_hand_jvp

    subroutine lh004_hand_vjp(y_initial, z_initial, x1_final_b, x2_final_b, &
        x1_final, x2_final, y_initial_b, z_initial_b)
        real(dp), intent(in) :: y_initial, z_initial
        real(dp), intent(in) :: x1_final_b, x2_final_b
        real(dp), intent(out) :: x1_final, x2_final
        real(dp), intent(out) :: y_initial_b, z_initial_b
        integer :: iterations

        call iteration_count(y_initial, z_initial, iterations)
        x1_final = real(iterations, dp)*abs(z_initial)
        x2_final = real(iterations, dp)*y_initial
        y_initial_b = real(iterations, dp)*x2_final_b
        z_initial_b = real(iterations, dp)*sign(1.0_dp, z_initial)*x1_final_b
    end subroutine lh004_hand_vjp

    subroutine iteration_count(y_initial, z_initial, iterations)
        real(dp), intent(in) :: y_initial, z_initial
        integer, intent(out) :: iterations
        real(dp) :: x1

        x1 = 0.0_dp
        iterations = 0
        do
            iterations = iterations + 1
            x1 = x1 + abs(z_initial)
            if (.not. (x1 <= y_initial .and. iterations <= 100)) exit
        end do
    end subroutine iteration_count

end module tapenade_set01_lh004_hand
