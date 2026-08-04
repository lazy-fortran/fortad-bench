subroutine bruss(n, z, y)
    integer, intent(in) :: n
    real(8), intent(in) :: z(n)
    real(8), intent(out) :: y
    real(8) :: u, v, du, dv, dt
    integer :: i
    dt = 0.01d0
    u = 1.0d0
    v = 3.0d0
    y = 0.0d0
    do i = 1, n
        du = 1.0d0 - 4.0d0*u + u*u*v + 0.1d0*z(i)
        dv = 3.0d0*u - u*u*v
        u = u + dt*du
        v = v + dt*dv
        y = y + u*u + v*v
    end do
    y = y/real(n, 8)
end subroutine bruss
