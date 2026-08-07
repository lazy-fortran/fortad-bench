module tapenade_set01_lh034_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: set01_lh034

contains

    pure function lh034_callback(value) result(output)
        real(dp), intent(in) :: value
        real(dp) :: output

        output = value*value + 0.25_dp*value
    end function lh034_callback

    subroutine set01_lh034(a0, b0, x, n, root)
        real(dp), intent(in) :: a0, b0, x
        integer, intent(in) :: n
        real(dp), intent(out) :: root
        real(dp) :: a, b, m
        integer :: i

        a = a0
        b = b0
        do i = 1, n
            m = (a + b)/2.0_dp
            if ((lh034_callback(a) - x)*(lh034_callback(m) - x) <= &
                0.0_dp) then
                b = m
            else
                a = m
            end if
        end do
        root = (a + b)/2.0_dp
    end subroutine set01_lh034

end module tapenade_set01_lh034_case
