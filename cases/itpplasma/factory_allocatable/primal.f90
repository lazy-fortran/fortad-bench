module factory_profile_models
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: profile_t, linear_profile_t, quadratic_profile_t, make_profile

    type :: coefficient_pair_t
        real(dp) :: leading
        real(dp) :: trailing
    end type coefficient_pair_t

    type, abstract :: profile_t
    end type profile_t

    type, extends(profile_t) :: linear_profile_t
        type(coefficient_pair_t) :: coefficients
    end type linear_profile_t

    type, extends(profile_t) :: quadratic_profile_t
        type(coefficient_pair_t) :: coefficients
    end type quadratic_profile_t

contains

    subroutine make_profile(kind, leading, trailing, profile)
        integer, intent(in) :: kind
        real(dp), intent(in) :: leading, trailing
        class(profile_t), allocatable, intent(out) :: profile
        type(linear_profile_t) :: linear
        type(quadratic_profile_t) :: quadratic

        select case (kind)
        case (1)
            linear%coefficients%leading = leading
            linear%coefficients%trailing = trailing
            allocate (profile, source=linear)
        case default
            quadratic%coefficients%leading = leading
            quadratic%coefficients%trailing = trailing
            allocate (profile, source=quadratic)
        end select
    end subroutine make_profile
end module factory_profile_models

module factory_allocatable_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use factory_profile_models, only: profile_t, linear_profile_t, &
        quadratic_profile_t
    implicit none
    private

    public :: evaluate_profile

contains

    function evaluate_profile(profile, x) result(y)
        class(profile_t), intent(in) :: profile
        real(dp), intent(in) :: x
        real(dp) :: y

        select type (profile)
            type is (linear_profile_t)
            y = profile%coefficients%leading*x + &
                profile%coefficients%trailing
            type is (quadratic_profile_t)
            y = profile%coefficients%leading*x*x + &
                profile%coefficients%trailing*x
        class default
            y = 0.0_dp
        end select
    end function evaluate_profile
end module factory_allocatable_kernel
