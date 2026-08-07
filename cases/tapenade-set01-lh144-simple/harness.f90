program lh144_hand_oracle
  implicit none
  real :: x, y, dx, dy, x0, y0, xp, yp, fx, fy, fdx, fdy
  real, parameter :: h = 1.0e-4
  x0 = 0.7; y0 = 1.2; dx = 0.3; dy = -0.7
  call hand(x0, y0, fx, fy)
  call hand(x0+h*dx, y0+h*dy, xp, yp)
  fdx = (xp-fx)/h; fdy = (yp-fy)/h
  if (abs(fdx-(4.0*x0**3*y0**4*dx+4.0*x0**4*y0**3*dy)) > 2.0e-2) error stop 1
  if (abs(fdy-5.0*dy) > 2.0e-2) error stop 2
  print '(A)', 'oracle_status: pass'
contains
  subroutine hand(x, y, xo, yo)
    real, intent(in) :: x, y
    real, intent(out) :: xo, yo
    real :: a
    a = x*y
    xo = (a*a)*(a*a)
    yo = 5.0*y
  end subroutine hand
end program lh144_hand_oracle
