module polymorphic_select_type_hand_reverse
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use polymorphic_field_models, only: field_model_t, linear_field_t, &
        quadratic_field_t
    implicit none
    private

    public :: field_response_hand_vjp

contains

    pure subroutine field_response_hand_vjp(model, x, y, y_b, x_b)
        class(field_model_t), intent(in) :: model
        real(dp), intent(in) :: x
        real(dp), intent(out) :: y
        real(dp), intent(in) :: y_b
        real(dp), intent(out) :: x_b

        select type (model)
            type is (linear_field_t)
            y = model%scale*x + model%offset
            x_b = y_b*model%scale
            type is (quadratic_field_t)
            y = model%curvature*x*x + model%tilt*x
            x_b = y_b*(2.0_dp*model%curvature*x + model%tilt)
        class default
            y = 0.0_dp
            x_b = 0.0_dp
        end select
    end subroutine field_response_hand_vjp
end module polymorphic_select_type_hand_reverse
