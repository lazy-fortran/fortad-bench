! The same kernel in plain Fortran, for fortad to differentiate. fortad reads
! ordinary Fortran; the bind(C) form above exists only so Enzyme's C driver can
! reach it.
subroutine dot_sin(n, a, b, s)
    integer, intent(in) :: n
    real(8), intent(in) :: a(n)
    real(8), intent(in) :: b(n)
    real(8), intent(out) :: s
    integer :: i
    s = 0.0d0
    do i = 1, n
        s = s + a(i)*sin(b(i))
    end do
end subroutine dot_sin
