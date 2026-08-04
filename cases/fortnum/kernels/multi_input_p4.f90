subroutine multi_input_p4(n, z, y)
    !! Sum of sines plus half the square of the sum, 4 inputs.
    !!
    !! The fortnum operator applied over a batch. Batching is not decoration:
    !! one scalar evaluation is far below timer resolution, and a batch is also
    !! how the operator is used - fortnum's callers apply it across a mesh or a
    !! quadrature rule, not once.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(4*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value, sines, total

    y = 0.0_dp
    do i = 1, n
        base = (4)*(i - 1)
        sines = sin(z(base + 1)) + sin(z(base + 2)) + sin(z(base + 3)) + &
            sin(z(base + 4))
        total = z(base + 1) + z(base + 2) + z(base + 3) + z(base + 4)
        value = sines + total*total/2.0_dp
        y = y + value
    end do
end subroutine multi_input_p4
