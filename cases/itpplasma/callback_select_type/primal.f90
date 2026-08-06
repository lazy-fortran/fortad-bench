module callback_select_type_models
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: callback_model_t, linear_callback_t, quadratic_callback_t

    type, abstract :: callback_model_t
    end type callback_model_t

    type, extends(callback_model_t) :: linear_callback_t
        real(dp) :: scale
        real(dp) :: shift
    end type linear_callback_t

    type, extends(callback_model_t) :: quadratic_callback_t
        real(dp) :: curvature
        real(dp) :: tilt
    end type quadratic_callback_t
end module callback_select_type_models

module callback_select_type_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use callback_select_type_models, only: callback_model_t, &
        linear_callback_t, quadratic_callback_t
    implicit none
    private

    public :: evaluate_callback

contains

    function evaluate_callback(callback, x) result(y)
        class(callback_model_t), intent(in) :: callback
        real(dp), intent(in) :: x
        real(dp) :: y

        select type (callback)
            type is (linear_callback_t)
            y = callback%scale*x + callback%shift
            type is (quadratic_callback_t)
            y = callback%curvature*x*x + callback%tilt*x
        class default
            y = 0.0_dp
        end select
    end function evaluate_callback
end module callback_select_type_kernel
