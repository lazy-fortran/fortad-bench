program lh192_hand_oracle
  implicit none
  real :: x, a, b, c, dx, da, db, dc, h
  real :: xo, yo, co, xp, yp, cp
  x=1.7; a=2.0; b=-0.25; c=0.8
  dx=0.3; da=-0.4; db=0.2; dc=-0.1; h=1.0e-3
  call hand(x,a,b,c,xo,yo,co)
  call hand(x+h*dx,a+h*da,b+h*db,c+h*dc,xp,yp,cp)
  if (abs((xp-xo)/h-(dx*a*b*c+x*(da*b+a*db)*c+x*a*b*dc)) > 1.0e-2) error stop 1
  if (abs((yp-yo)/h-(da*b+a*db)) > 1.0e-2) error stop 2
  if (abs((cp-co)/h-dx*2.5) > 1.0e-2) error stop 3
  print '(A)', 'oracle_status: pass'
contains
  subroutine hand(x,a,b,c,xo,yo,co)
    real, intent(in) :: x,a,b,c
    real, intent(out) :: xo,yo,co
    yo=a*b; xo=x*yo*c; co=x*2.5
  end subroutine hand
end program lh192_hand_oracle
