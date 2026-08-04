! Benchmark kernel: a nonlinear reduction over two input arrays.
!
!   s = sum_i a(i) * sin(b(i))
!
! Chosen because it is the smallest kernel that is honestly representative:
! nonlinear in one input, bilinear across both, memory-bound at large n and
! transcendental-bound at small n, and with a loop-carried scalar accumulator
! that every AD tool has to handle.
subroutine dot_sin(n, a, b, s) bind(C, name="dot_sin")
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: a(n)
    real(c_double), intent(in) :: b(n)
    real(c_double), intent(out) :: s
    integer :: i

    s = 0.0d0
    do i = 1, n
        s = s + a(i)*sin(b(i))
    end do
end subroutine dot_sin
