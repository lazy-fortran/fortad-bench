module polymorphic_select_type_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use polymorphic_field_models, only: field_model_t, linear_field_t, &
        quadratic_field_t
    implicit none
    private

    public :: field_response_hand_jvp

contains

    pure subroutine field_response_hand_jvp(model, x, x_d, y, y_d)
        class(field_model_t), intent(in) :: model
        real(dp), intent(in) :: x
        real(dp), intent(in) :: x_d
        real(dp), intent(out) :: y
        real(dp), intent(out) :: y_d

        select type (model)
            type is (linear_field_t)
            y = model%scale*x + model%offset
            y_d = model%scale*x_d
            type is (quadratic_field_t)
            y = model%curvature*x*x + model%tilt*x
            y_d = (2.0_dp*model%curvature*x + model%tilt)*x_d
        class default
            y = 0.0_dp
            y_d = 0.0_dp
        end select
    end subroutine field_response_hand_jvp
end module polymorphic_select_type_hand
