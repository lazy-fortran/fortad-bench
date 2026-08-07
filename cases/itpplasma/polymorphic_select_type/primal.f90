module polymorphic_field_models
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: field_model_t, linear_field_t, quadratic_field_t

    type, abstract :: field_model_t
    contains
        procedure(field_response_iface), deferred :: response
    end type field_model_t

    abstract interface
        pure function field_response_iface(self, x) result(y)
            import field_model_t, dp
            class(field_model_t), intent(in) :: self
            real(dp), intent(in) :: x
            real(dp) :: y
        end function field_response_iface
    end interface

    type, extends(field_model_t) :: linear_field_t
        real(dp) :: scale
        real(dp) :: offset
    contains
        procedure :: response => linear_response
    end type linear_field_t

    type, extends(field_model_t) :: quadratic_field_t
        real(dp) :: curvature
        real(dp) :: tilt
    contains
        procedure :: response => quadratic_response
    end type quadratic_field_t

contains

    pure function linear_response(self, x) result(y)
        class(linear_field_t), intent(in) :: self
        real(dp), intent(in) :: x
        real(dp) :: y

        y = self%scale*x + self%offset
    end function linear_response

    pure function quadratic_response(self, x) result(y)
        class(quadratic_field_t), intent(in) :: self
        real(dp), intent(in) :: x
        real(dp) :: y

        y = self%curvature*x*x + self%tilt*x
    end function quadratic_response
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
            y = model%response(x)
            type is (quadratic_field_t)
            y = model%response(x)
            class default
            y = 0.0_dp
        end select
    end function field_response
end module polymorphic_field_kernel
