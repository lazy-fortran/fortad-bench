program check_v130
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use v130_jvp_ad, only: v130_jvp
  use v130_vjp_ad, only: v130_vjp
  implicit none
  real :: x, xd, y, yd, yb, xb

  x = 1.25
  xd = -0.4
  call v130_jvp(x, xd, y, yd)
  if (.not. ieee_is_finite(y) .or. abs(y - x*x) > 1.0e-6) error stop 1
  if (abs(yd - 2.0*x*xd) > 1.0e-6) error stop 2

  yb = -1.3
  call v130_vjp(x, y, yb, xb)
  if (abs(xb - yb*2.0*x) > 1.0e-6) error stop 3
  print '(a)', 'harness_status: pass'
end program check_v130
