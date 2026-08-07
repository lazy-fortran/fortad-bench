module tapenade_set01_lh008_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh008_hand_jvp, lh008_hand_vjp

contains

    subroutine lh008_hand_jvp(y, y_d, x, x_d, z, z_d, objective, objective_d)
        real(dp), intent(in) :: y, y_d
        real(dp), intent(out) :: x, x_d, z, z_d, objective, objective_d
        real(dp), parameter :: first_scale = 10.5_dp
        real(dp), parameter :: second_scale = 11.5_dp

        x = first_scale * y
        x_d = first_scale * y_d
        z = second_scale * y
        z_d = second_scale * y_d
        objective = x + 0.5_dp * z
        objective_d = x_d + 0.5_dp * z_d
    end subroutine lh008_hand_jvp

    subroutine lh008_hand_vjp(y, objective_b, y_b)
        real(dp), intent(in) :: y, objective_b
        real(dp), intent(out) :: y_b
        y_b = (10.5_dp + 0.5_dp * 11.5_dp) * objective_b
    end subroutine lh008_hand_vjp

end module tapenade_set01_lh008_hand
