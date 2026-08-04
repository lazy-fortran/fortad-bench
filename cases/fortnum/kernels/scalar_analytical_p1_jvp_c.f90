subroutine scalar_analytical_p1_jvp(n, z, y) bind(C, name="scalar_analytical_p1_jvp")
    !! scalar_analytical_p1_jvp, as Enzyme differentiates it in fortnum, applied over a batch.
    !!
    !! Batching is not decoration: one scalar evaluation is far below timer
    !! resolution, and a batch is how the operator is used.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: z(*)
    real(c_double), intent(out) :: y
    integer :: i, base
    real(c_double) :: value

    y = 0.0_c_double
    do i = 1, n
        base = (2)*(i - 1)
        value = (cos(z(base + 1)) + z(base + 1))*z(base + 2)
        y = y + value
    end do
end subroutine scalar_analytical_p1_jvp
