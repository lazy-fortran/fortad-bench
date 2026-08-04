subroutine scalar_analytical_p1_jvp(n, z, y)
    !! scalar_analytical_p1_jvp, as Enzyme differentiates it in fortnum, applied over a batch.
    !!
    !! Batching is not decoration: one scalar evaluation is far below timer
    !! resolution, and a batch is how the operator is used.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(2*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value

    y = 0.0_dp
    do i = 1, n
        base = (2)*(i - 1)
        value = (cos(z(base + 1)) + z(base + 1))*z(base + 2)
        y = y + value
    end do
end subroutine scalar_analytical_p1_jvp
