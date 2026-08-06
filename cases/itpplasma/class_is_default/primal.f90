module class_is_models
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: response_t, scaled_response_t, scaled_leaf_t, fallback_response_t

    type, abstract :: response_t
    end type response_t

    type, abstract, extends(response_t) :: scaled_response_t
        real(dp) :: scale
    end type scaled_response_t

    type, extends(scaled_response_t) :: scaled_leaf_t
        real(dp) :: leaf_offset
    end type scaled_leaf_t

    type, extends(response_t) :: fallback_response_t
        real(dp) :: passive_tag
    end type fallback_response_t
end module class_is_models

module class_is_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use class_is_models, only: response_t, scaled_response_t
    implicit none
    private

    public :: evaluate_hierarchy

contains

    function evaluate_hierarchy(model, x) result(y)
        class(response_t), intent(in) :: model
        real(dp), intent(in) :: x
        real(dp) :: y

        select type (model)
        class is (scaled_response_t)
            y = model%scale*x
        class default
            y = x*x - 0.25_dp
        end select
    end function evaluate_hierarchy
end module class_is_kernel
