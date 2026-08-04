subroutine rk4(n, z, y) bind(C, name="rk4")
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: z(n)
    real(c_double), intent(out) :: y
    real(c_double) :: dt, k1, k2, k3, k4, state
    integer :: i
    dt = 2.1d0/real(n, 8)
    state = 1.0d0
    do i = 1, n
        k1 = -1.2d0*state + 0.05d0*z(i)
        k2 = -1.2d0*(state + 0.5d0*dt*k1) + 0.05d0*z(i)
        k3 = -1.2d0*(state + 0.5d0*dt*k2) + 0.05d0*z(i)
        k4 = -1.2d0*(state + dt*k3) + 0.05d0*z(i)
        state = state + dt*(k1 + 2.0d0*k2 + 2.0d0*k3 + k4)/6.0d0
    end do
    y = state
end subroutine rk4
