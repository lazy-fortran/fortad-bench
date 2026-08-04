subroutine singular_trace_integrand(n, z, y) bind(C, name="singular_trace_integrand")
    !! singular_trace_integrand, as Enzyme differentiates it in fortnum, applied over a batch.
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
        value = exp(z(base + 2))/sqrt(z(base + 1))
        y = y + value
    end do
end subroutine singular_trace_integrand
