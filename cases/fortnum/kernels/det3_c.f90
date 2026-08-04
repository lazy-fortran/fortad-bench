subroutine det3(n, z, y) bind(C, name="det3")
    !! Determinant of a 3x3 matrix.
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
        base = (9)*(i - 1)
        value = z(base + 1)*(z(base + 5)*z(base + 9) - z(base + 8)*z(base + 6)) &
                - z(base + 4)*(z(base + 2)*z(base + 9) - z(base + 8)*z(base + 3)) &
                + z(base + 7)*(z(base + 2)*z(base + 6) - z(base + 5)*z(base + 3))
        y = y + value
    end do
end subroutine det3
