subroutine multi_input_p16(n, z, y) bind(C, name="multi_input_p16")
    !! Sum of sines plus half the square of the sum, 16 inputs.
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
        base = (16)*(i - 1)
        sines = sin(z(base + 1)) + sin(z(base + 2)) + sin(z(base + 3)) + &
            sin(z(base + 4)) + sin(z(base + 5)) + sin(z(base + 6)) + sin(z(base + &
            7)) + sin(z(base + 8)) + sin(z(base + 9)) + sin(z(base + 10)) + &
            sin(z(base + 11)) + sin(z(base + 12)) + sin(z(base + 13)) + &
            sin(z(base + 14)) + sin(z(base + 15)) + sin(z(base + 16))
        total = z(base + 1) + z(base + 2) + z(base + 3) + z(base + 4) + z(base + &
            5) + z(base + 6) + z(base + 7) + z(base + 8) + z(base + 9) + z(base + &
            10) + z(base + 11) + z(base + 12) + z(base + 13) + z(base + 14) + &
            z(base + 15) + z(base + 16)
        value = sines + total*total/2.0_c_double
        y = y + value
    end do
end subroutine multi_input_p16
