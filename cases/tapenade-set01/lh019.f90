module tapenade_set01_lh019_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: real8_diff, set01_lh019

    type :: real8_diff
        real(dp) :: v
        integer :: tag
    end type real8_diff

contains

    subroutine set01_lh019(x, y, n, output)
        type(real8_diff), intent(in) :: x
        type(real8_diff), intent(in) :: y
        integer, intent(in) :: n
        real(dp), intent(out) :: output

        output = x%v
        if (n >= 5) then
            output = x%v*y%v
        end if
    end subroutine set01_lh019

end module tapenade_set01_lh019_case
