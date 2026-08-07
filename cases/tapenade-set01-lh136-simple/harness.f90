program lh136_hand_oracle
  implicit none
  real(kind=8) :: x(4), xp(4), y(2), yp(2), h
  integer :: i
  x = (/3.7d0, 0.7d0, 0.5d0, 0.5d0/)
  h = 1.0d-6
  call hand(x, y)
  do i = 1, 4
    xp = x; xp(i) = xp(i) + h
    call hand(xp, yp)
    if (abs((yp(1)-y(1))/h) > 1.0d4) error stop 1
    if (abs((yp(2)-y(2))/h) > 1.0d4) error stop 2
  end do
  print '(A)', 'oracle_status: pass'
contains
  subroutine hand(x, y)
    real(kind=8), intent(in) :: x(4)
    real(kind=8), intent(out) :: y(2)
    real(kind=8) :: t, q, r
    t = tan(x(3)*x(4))
    q = x(2)-t
    r = x(1)*t/q
    y(1) = r; y(2) = r*x(2)
  end subroutine hand
end program lh136_hand_oracle
