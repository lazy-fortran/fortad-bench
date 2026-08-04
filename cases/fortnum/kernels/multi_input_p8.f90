subroutine multi_input_p8(n, z, y)
    !! Sum of sines plus half the square of the sum, 8 inputs.
    !!
    !! The fortnum operator applied over a batch. Batching is not decoration:
    !! one scalar evaluation is far below timer resolution, and a batch is also
    !! how the operator is used - fortnum's callers apply it across a mesh or a
    !! quadrature rule, not once.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(8*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value, sines, total

    y = 0.0_dp
    do i = 1, n
        base = (8)*(i - 1)
        sines = sin(z(base + 1)) + sin(z(base + 2)) + sin(z(base + 3)) + &
            sin(z(base + 4)) + sin(z(base + 5)) + sin(z(base + 6)) + sin(z(base + &
            7)) + sin(z(base + 8))
        total = z(base + 1) + z(base + 2) + z(base + 3) + z(base + 4) + z(base + &
            5) + z(base + 6) + z(base + 7) + z(base + 8)
        value = sines + total*total/2.0_dp
        y = y + value
    end do
end subroutine multi_input_p8
