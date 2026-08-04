subroutine lagrange4(n, z, y) bind(C, name="lagrange4")
    !! Lagrange interpolation through four samples.
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
    real(c_double) :: value, b1, b2, b3, b4

    y = 0.0_c_double
    do i = 1, n
        base = (5)*(i - 1)
        b1 = (z(base + 1) - 0.0_c_double)*(z(base + 1) - 1.0_c_double)* &
             (z(base + 1) - 2.0_c_double)/((-1.0_c_double)*(-2.0_c_double)*(-3.0_c_double))
        b2 = (z(base + 1) + 1.0_c_double)*(z(base + 1) - 1.0_c_double)* &
             (z(base + 1) - 2.0_c_double)/((1.0_c_double)*(-1.0_c_double)*(-2.0_c_double))
        b3 = (z(base + 1) + 1.0_c_double)*(z(base + 1) - 0.0_c_double)* &
             (z(base + 1) - 2.0_c_double)/((2.0_c_double)*(1.0_c_double)*(-1.0_c_double))
        b4 = (z(base + 1) + 1.0_c_double)*(z(base + 1) - 0.0_c_double)* &
             (z(base + 1) - 1.0_c_double)/((3.0_c_double)*(2.0_c_double)*(1.0_c_double))
        value = z(base + 2)*b1 + z(base + 3)*b2 + z(base + 4)*b3 + z(base + 5)*b4
        y = y + value
    end do
end subroutine lagrange4
