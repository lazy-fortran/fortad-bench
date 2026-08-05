! Small, deterministic vector kernel used only for the compiler matrix.
! Its arithmetic is deliberately free of transcendental calls so the matrix
! tests compiler vectorisation rather than a libm profitability decision.
subroutine affine_sum(n, a, b, s)
  integer, intent(in) :: n
  real(8), intent(in) :: a(n), b(n)
  real(8), intent(out) :: s
  integer :: i

  s = 0.0d0
  do i = 1, n
    s = s + a(i)*b(i) + 0.5d0*a(i)
  end do
end subroutine affine_sum
