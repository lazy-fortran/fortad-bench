! A nonlinear loop-carried recurrence: the one loop shape that genuinely needs
! stored history in reverse mode. Both engines must tape something here, so
! this is the fair fight on the case fortad's other tricks do not cover.
subroutine recur(n, a, b, s)
    integer, intent(in) :: n
    real(8), intent(in) :: a(n)
    real(8), intent(in) :: b(n)
    real(8), intent(out) :: s
    real(8) :: u
    integer :: i
    u = 1.0d0
    s = 0.0d0
    do i = 1, n
        u = u*exp(0.01d0*a(i)) + 0.1d0*b(i)
        s = s + u*u
    end do
end subroutine recur
