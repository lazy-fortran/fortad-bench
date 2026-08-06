module polymorphic_field_models
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: field_model_t, linear_field_t, quadratic_field_t

    type, abstract :: field_model_t
    end type field_model_t

    type, extends(field_model_t) :: linear_field_t
        real(dp) :: scale
        real(dp) :: offset
    end type linear_field_t

    type, extends(field_model_t) :: quadratic_field_t
        real(dp) :: curvature
        real(dp) :: tilt
    end type quadratic_field_t
end module polymorphic_field_models

module polymorphic_field_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use polymorphic_field_models, only: field_model_t, linear_field_t, &
        quadratic_field_t
    implicit none
    private

    public :: field_response

contains

    function field_response(model, x) result(y)
        class(field_model_t), intent(in) :: model
        real(dp), intent(in) :: x
        real(dp) :: y

        select type (model)
            type is (linear_field_t)
            y = model%scale*x + model%offset
            type is (quadratic_field_t)
            y = model%curvature*x*x + model%tilt*x
        class default
            y = 0.0_dp
        end select
    end function field_response
end module polymorphic_field_kernel
