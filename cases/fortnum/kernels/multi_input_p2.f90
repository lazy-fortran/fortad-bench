subroutine multi_input_p2(n, z, y)
    !! Sum of sines plus half the square of the sum, 2 inputs.
    !!
    !! The fortnum operator applied over a batch. Batching is not decoration:
    !! one scalar evaluation is far below timer resolution, and a batch is also
    !! how the operator is used - fortnum's callers apply it across a mesh or a
    !! quadrature rule, not once.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(2*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value, sines, total

    y = 0.0_dp
    do i = 1, n
        base = (2)*(i - 1)
        sines = sin(z(base + 1)) + sin(z(base + 2))
        total = z(base + 1) + z(base + 2)
        value = sines + total*total/2.0_dp
        y = y + value
    end do
end subroutine multi_input_p2
