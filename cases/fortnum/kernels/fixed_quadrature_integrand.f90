subroutine fixed_quadrature_integrand(n, z, y)
    !! fixed_quadrature_integrand, as Enzyme differentiates it in fortnum, applied over a batch.
    !!
    !! Batching is not decoration: one scalar evaluation is far below timer
    !! resolution, and a batch is how the operator is used.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(5*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value

    y = 0.0_dp
    do i = 1, n
        base = (5)*(i - 1)
        value = exp(z(base + 2)*z(base + 1)) + sin(z(base + 3)*z(base + 1)) + &
                z(base + 4)*z(base + 1)*z(base + 1) + &
                z(base + 5)*z(base + 1)*z(base + 1)*z(base + 1)
        y = y + value
    end do
end subroutine fixed_quadrature_integrand
