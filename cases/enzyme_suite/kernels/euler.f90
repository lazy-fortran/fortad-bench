subroutine euler(n, z, y)
    integer, intent(in) :: n
    real(8), intent(in) :: z(n)
    real(8), intent(out) :: y
    real(8) :: dt, state
    integer :: i
    dt = 2.1d0/real(n, 8)
    state = 1.0d0
    do i = 1, n
        state = state + dt*(-1.2d0*state + 0.05d0*z(i))
    end do
    y = state
end subroutine euler
