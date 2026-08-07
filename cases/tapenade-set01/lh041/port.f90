! Bounded standard-conforming port of nonRegressions/set01/lh041/program.f.
! The COMMON state and fixed-form labels are made explicit so that the
! numerical probe isolates the nested-loop derivative from those exact-source
! boundaries.
module tapenade_set01_lh041_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh041(a, b, q, result)
        real(dp), intent(in) :: a, b, q
        real(dp), intent(out) :: result
        real(dp) :: tab(5, 3), x(5, 3, 2)
        integer :: i, j

        tab = 1.0_dp
        x = 0.5_dp

        do i = 1, 3
            do j = 1, 3
                x(i, j, 1) = q*x(i, j, 1)
                x(i, j, 2) = q*x(i, j, 2)
            end do
        end do
        do i = 1, 3
            do j = 1, i
                tab(i, j) = x(i, j, 1)*a + real(i, dp)
            end do
        end do

        do i = 1, 3
            do j = 1, 3
                tab(i, j) = a*x(i, j, 1) + b
            end do
        end do

        do i = 1, 3
            do j = 1, 3
                x(i, j, 1) = 10.0_dp*x(i, j, 1)
                x(i, j, 2) = 10.0_dp*x(i, j, 2)
            end do
        end do
        do i = 1, 3
            do j = 1, i
                tab(i, j) = x(i, j, 1)*a + real(i, dp)
            end do
        end do

        result = a*tab(2, 2) + b + x(2, 2, 1)
    end subroutine set01_lh041
end module tapenade_set01_lh041_case
