module callback_select_type_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use callback_select_type_models, only: callback_model_t, &
        linear_callback_t, quadratic_callback_t
    implicit none
    private

    public :: evaluate_callback_hand_jvp

contains

    pure subroutine evaluate_callback_hand_jvp(callback, x, x_d, y, y_d)
        class(callback_model_t), intent(in) :: callback
        real(dp), intent(in) :: x, x_d
        real(dp), intent(out) :: y, y_d

        select type (callback)
            type is (linear_callback_t)
            y = callback%scale*x + callback%shift
            y_d = callback%scale*x_d
            type is (quadratic_callback_t)
            y = callback%curvature*x*x + callback%tilt*x
            y_d = (2.0_dp*callback%curvature*x + callback%tilt)*x_d
        class default
            y = 0.0_dp
            y_d = 0.0_dp
        end select
    end subroutine evaluate_callback_hand_jvp
end module callback_select_type_hand
