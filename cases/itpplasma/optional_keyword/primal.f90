module optional_keyword_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_optional

contains

    pure function evaluate_optional(x, coefficient) result(y)
        real(dp), intent(in) :: x
        real(dp), intent(in), optional :: coefficient
        real(dp) :: y

        y = x
        if (present(coefficient)) y = y + x*coefficient
    end function evaluate_optional
end module optional_keyword_kernel
