subroutine vector_root_residual_two(n, z, y)
    !! vector_root_residual_two, as Enzyme differentiates it in fortnum, applied over a batch.
    !!
    !! Batching is not decoration: one scalar evaluation is far below timer
    !! resolution, and a batch is how the operator is used.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(4*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value

    y = 0.0_dp
    do i = 1, n
        base = (4)*(i - 1)
        value = z(base + 1) + z(base + 2)*z(base + 2) + 0.0_dp*z(base + 3) - z(base + 4)
        y = y + value
    end do
end subroutine vector_root_residual_two
