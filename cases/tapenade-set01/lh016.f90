module tapenade_set01_lh016
    implicit none
    private
    public :: set01_lh016

contains

    subroutine set01_lh016(input, output)
        complex, intent(in) :: input(2)
        complex, intent(out) :: output(2)
        complex :: matrix(2, 2)
        integer :: i, j

        matrix(1, 1) = cmplx(1.0, 1.0)
        matrix(1, 2) = cmplx(1.0, 2.0)
        matrix(2, 1) = cmplx(2.0, 1.0)
        matrix(2, 2) = cmplx(2.0, 2.0)
        do i = 1, 2
            output(i) = cmplx(0.0, 0.0)
            do j = 1, 2
                output(i) = matrix(i, j) * input(1)
            end do
        end do
    end subroutine set01_lh016

end module tapenade_set01_lh016
