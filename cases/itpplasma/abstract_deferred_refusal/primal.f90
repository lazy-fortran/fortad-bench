module abstract_deferred_refusal_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: model_t, evaluate_deferred, make_model, destroy_model

    type, abstract :: model_t
        real(dp) :: bias = 0.0_dp
    contains
        procedure(model_value), deferred, pass(self) :: value
    end type model_t

    abstract interface
        pure function model_value(self, x) result(y)
            import :: dp, model_t
            class(model_t), intent(in) :: self
            real(dp), intent(in) :: x
            real(dp) :: y
        end function model_value
    end interface

    type, extends(model_t) :: affine_model_t
        real(dp) :: slope = 0.0_dp
    contains
        procedure, pass(self) :: value => affine_value
    end type affine_model_t

    type, extends(affine_model_t) :: square_model_t
        real(dp) :: curvature = 0.0_dp
    contains
        procedure, pass(self) :: value => square_value
    end type square_model_t

contains

    pure function affine_value(self, x) result(y)
        class(affine_model_t), intent(in) :: self
        real(dp), intent(in) :: x
        real(dp) :: y

        y = self%slope*x + self%bias
    end function affine_value

    pure function square_value(self, x) result(y)
        class(square_model_t), intent(in) :: self
        real(dp), intent(in) :: x
        real(dp) :: y

        y = self%curvature*x*x + self%slope*x + self%bias
    end function square_value

    subroutine make_model(kind, slope, curvature, bias, model)
        integer, intent(in) :: kind
        real(dp), intent(in) :: slope, curvature, bias
        class(model_t), allocatable, intent(out) :: model

        select case (kind)
        case (1)
            allocate(affine_model_t :: model)
            select type (model)
            type is (affine_model_t)
                model%slope = slope
                model%bias = bias
            end select
        case (2)
            allocate(square_model_t :: model)
            select type (model)
            type is (square_model_t)
                model%slope = slope
                model%curvature = curvature
                model%bias = bias
            end select
        case default
            error stop "unknown model kind"
        end select
    end subroutine make_model

    subroutine destroy_model(model)
        class(model_t), allocatable, intent(inout) :: model

        if (allocated(model)) deallocate(model)
    end subroutine destroy_model

    function evaluate_deferred(model, x) result(y)
        class(model_t), intent(in) :: model
        real(dp), intent(in) :: x
        real(dp) :: y

        y = model%value(x)
    end function evaluate_deferred

end module abstract_deferred_refusal_kernel
