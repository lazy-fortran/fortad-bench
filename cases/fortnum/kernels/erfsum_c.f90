subroutine erfsum(n, z, y) bind(C, name="erfsum")
    !! Elementwise erf, summed.
    !!
    !! The fortnum operator applied over a batch. Batching is not decoration:
    !! one scalar evaluation is far below timer resolution, and a batch is also
    !! how the operator is used - fortnum's callers apply it across a mesh or a
    !! quadrature rule, not once.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: z(*)
    real(c_double), intent(out) :: y
    integer :: i, base
    real(c_double) :: value

    y = 0.0_c_double
    do i = 1, n
        base = (1)*(i - 1)
        value = erf(z(base + 1))
        y = y + value
    end do
end subroutine erfsum
