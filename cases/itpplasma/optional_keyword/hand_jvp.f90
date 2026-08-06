module optional_keyword_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_optional_hand_jvp

contains

    pure subroutine evaluate_optional_hand_jvp(x, x_d, coefficient, y, y_d)
        real(dp), intent(in) :: x, x_d
        real(dp), intent(in), optional :: coefficient
        real(dp), intent(out) :: y, y_d

        y = x
        y_d = x_d
        if (present(coefficient)) then
            y = y + x*coefficient
            y_d = y_d + x_d*coefficient
        end if
    end subroutine evaluate_optional_hand_jvp
end module optional_keyword_hand
