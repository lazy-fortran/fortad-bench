subroutine det3(n, z, y)
    !! Determinant of a 3x3 matrix.
    !!
    !! The fortnum operator applied over a batch. Batching is not decoration:
    !! one scalar evaluation is far below timer resolution, and a batch is also
    !! how the operator is used - fortnum's callers apply it across a mesh or a
    !! quadrature rule, not once.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(9*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value

    y = 0.0_dp
    do i = 1, n
        base = (9)*(i - 1)
        value = z(base + 1)*(z(base + 5)*z(base + 9) - z(base + 8)*z(base + 6)) &
                - z(base + 4)*(z(base + 2)*z(base + 9) - z(base + 8)*z(base + 3)) &
                + z(base + 7)*(z(base + 2)*z(base + 6) - z(base + 5)*z(base + 3))
        y = y + value
    end do
end subroutine det3
