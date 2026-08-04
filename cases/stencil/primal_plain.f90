! A nonlinear stencil reduction, the shape a PDE residual takes: a
! per-element intermediate written to an array, then reduced. Both an AD tool's
! scatter adjoints and its handling of a written array are exercised.
subroutine stencil(n, a, b, s)
    integer, intent(in) :: n
    real(8), intent(in) :: a(n)
    real(8), intent(in) :: b(n)
    real(8), intent(out) :: s
    real(8) :: c(n)
    integer :: i
    s = 0.0d0
    do i = 1, n
        c(i) = sqrt(1.0d0 + a(i)*a(i))*tanh(b(i))
        s = s + c(i)*c(i)
    end do
end subroutine stencil
