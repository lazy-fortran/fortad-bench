! A nonlinear loop-carried recurrence: the one loop shape that genuinely needs
! stored history in reverse mode. Both engines must tape something here, so
! this is the fair fight on the case fortad's other tricks do not cover.
subroutine recur(n, a, b, s) bind(C, name="recur")
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: a(n)
    real(c_double), intent(in) :: b(n)
    real(c_double), intent(out) :: s
    real(c_double) :: u
    integer :: i
    u = 1.0d0
    s = 0.0d0
    do i = 1, n
        u = u*exp(0.01d0*a(i)) + 0.1d0*b(i)
        s = s + u*u
    end do
end subroutine recur
