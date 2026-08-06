module generic_dispatch_models
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_generic

    interface apply_gain
        module procedure apply_gain_scalar
        module procedure apply_gain_vector
    end interface apply_gain

contains

    pure function apply_gain_scalar(x, gain) result(y)
        real(dp), intent(in) :: x, gain
        real(dp) :: y

        y = gain*x + 0.5_dp
    end function apply_gain_scalar

    pure function apply_gain_vector(x, gain) result(y)
        real(dp), intent(in) :: x(:), gain
        real(dp) :: y

        y = gain*sum(x) + 1.0_dp
    end function apply_gain_vector

    pure function evaluate_generic(x) result(y)
        real(dp), intent(in) :: x
        real(dp) :: y
        real(dp) :: pair(2)
        real(dp) :: scalar_value, vector_value

        pair = [x, 0.25_dp*x]
        scalar_value = apply_gain(x, 2.0_dp)
        vector_value = apply_gain(pair, 3.0_dp)
        y = scalar_value + vector_value
    end function evaluate_generic
end module generic_dispatch_models
