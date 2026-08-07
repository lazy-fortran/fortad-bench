! Bounded standard-conforming port of nonRegressions/set01/lh051/program.f.
! The original fixed-form labeled DO is expressed structurally here; n and o
! remain integer controls and are held fixed for differentiation.
subroutine set01_lh051(x, y, z, n, o)
    implicit none
    integer, intent(in) :: n, o
    real, intent(inout) :: x(:), y(:), z(:)
    real :: a
    integer :: i, j, k

    a = 0.5*x(20)
    do i = 5 + o, n, 2
        z(i) = z(i-1) - 2.0*z(i) + z(i+1)
        x(i) = 3.0*x(i) - y(i+1)*y(i-1)
    end do

    a = x(10) + a
    j = 0
    ! The original natural loop visits j=3,6,...,102.  This fixed-count
    ! form is the same terminating path and avoids repairing the upstream
    ! control flow while keeping the port within the current AD boundary.
    do k = 1, 34
        j = j + 3
        x(j) = a*y(j-1)
        y(j+1) = z(j)*z(3) + x(j+1)
    end do
    a = 2.0*a + 3.0
end subroutine set01_lh051
