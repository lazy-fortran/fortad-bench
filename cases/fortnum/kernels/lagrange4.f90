subroutine lagrange4(n, z, y)
    !! Lagrange interpolation through four samples.
    !!
    !! The fortnum operator applied over a batch. Batching is not decoration:
    !! one scalar evaluation is far below timer resolution, and a batch is also
    !! how the operator is used - fortnum's callers apply it across a mesh or a
    !! quadrature rule, not once.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    integer, intent(in) :: n
    real(dp), intent(in) :: z(5*n)
    real(dp), intent(out) :: y
    integer :: i, base
    real(dp) :: value, b1, b2, b3, b4

    y = 0.0_dp
    do i = 1, n
        base = (5)*(i - 1)
        b1 = (z(base + 1) - 0.0_dp)*(z(base + 1) - 1.0_dp)* &
             (z(base + 1) - 2.0_dp)/((-1.0_dp)*(-2.0_dp)*(-3.0_dp))
        b2 = (z(base + 1) + 1.0_dp)*(z(base + 1) - 1.0_dp)* &
             (z(base + 1) - 2.0_dp)/((1.0_dp)*(-1.0_dp)*(-2.0_dp))
        b3 = (z(base + 1) + 1.0_dp)*(z(base + 1) - 0.0_dp)* &
             (z(base + 1) - 2.0_dp)/((2.0_dp)*(1.0_dp)*(-1.0_dp))
        b4 = (z(base + 1) + 1.0_dp)*(z(base + 1) - 0.0_dp)* &
             (z(base + 1) - 1.0_dp)/((3.0_dp)*(2.0_dp)*(1.0_dp))
        value = z(base + 2)*b1 + z(base + 3)*b2 + z(base + 4)*b3 + z(base + 5)*b4
        y = y + value
    end do
end subroutine lagrange4
