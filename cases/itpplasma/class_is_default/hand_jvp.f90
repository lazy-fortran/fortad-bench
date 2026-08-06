module class_is_default_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use class_is_models, only: response_t, scaled_response_t
    implicit none
    private

    public :: evaluate_hierarchy_hand_jvp

contains

    pure subroutine evaluate_hierarchy_hand_jvp(model, x, x_d, y, y_d)
        class(response_t), intent(in) :: model
        real(dp), intent(in) :: x, x_d
        real(dp), intent(out) :: y, y_d

        select type (model)
        class is (scaled_response_t)
            y = model%scale*x
            y_d = model%scale*x_d
        class default
            y = x*x - 0.25_dp
            y_d = 2.0_dp*x*x_d
        end select
    end subroutine evaluate_hierarchy_hand_jvp
end module class_is_default_hand
