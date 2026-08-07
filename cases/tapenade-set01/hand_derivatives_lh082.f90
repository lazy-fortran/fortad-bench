! Independent primal/finite-difference oracle for bounded set01_lh082.
module tapenade_set01_lh082_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh082_primal(a, n, x)
        integer, intent(in) :: n
        real(dp), intent(inout) :: a(1:n+5)
        real(dp), intent(in) :: x
        integer :: i
        a(5) = x*x
        a(4) = 8.0_dp*a(3)
        do i = 1, n
            a(i) = a(i)*a(n-i)
            a(i-1) = 2.0_dp*a(i-1)
            a(i-2) = 3.0_dp*a(i+3)
        end do
    end subroutine lh082_primal
end module tapenade_set01_lh082_hand
