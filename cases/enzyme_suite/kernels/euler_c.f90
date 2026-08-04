subroutine euler(n, z, y) bind(C, name="euler")
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: z(n)
    real(c_double), intent(out) :: y
    real(c_double) :: dt, state
    integer :: i
    dt = 2.1d0/real(n, 8)
    state = 1.0d0
    do i = 1, n
        state = state + dt*(-1.2d0*state + 0.05d0*z(i))
    end do
    y = state
end subroutine euler
