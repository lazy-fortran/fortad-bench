subroutine multi_input_p4(n, z, y) bind(C, name="multi_input_p4")
    !! Sum of sines plus half the square of the sum, 4 inputs.
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
    real(c_double) :: value, sines, total

    y = 0.0_c_double
    do i = 1, n
        base = (4)*(i - 1)
        sines = sin(z(base + 1)) + sin(z(base + 2)) + sin(z(base + 3)) + &
            sin(z(base + 4))
        total = z(base + 1) + z(base + 2) + z(base + 3) + z(base + 4)
        value = sines + total*total/2.0_c_double
        y = y + value
    end do
end subroutine multi_input_p4
