subroutine bruss(n, z, y) bind(C, name="bruss")
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: z(n)
    real(c_double), intent(out) :: y
    real(c_double) :: u, v, du, dv, dt
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
