! The same kernel with a C-callable interface, for Enzyme's driver.
subroutine stencil(n, a, b, s) bind(C, name="stencil")
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none
    integer(c_int), intent(in), value :: n
    real(c_double), intent(in) :: a(n)
    real(c_double), intent(in) :: b(n)
    real(c_double), intent(out) :: s
    real(c_double) :: c(n)
    integer :: i

    s = 0.0d0
    do i = 1, n
        c(i) = sqrt(1.0d0 + a(i)*a(i))*tanh(b(i))
        s = s + c(i)*c(i)
    end do
end subroutine stencil
