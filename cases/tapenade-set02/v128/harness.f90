program check_v128
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use v128_jvp_ad, only: v128_jvp
  use v128_vjp_ad, only: v128_vjp
  implicit none
  real :: x(2), xd(2), y, yd, yb, xb(2), expected

  x = [1.2, -0.4]
  xd = [0.3, -0.8]
  call v128_jvp(2, x, xd, y, yd)
  expected = exp(-0.5*x(1))
  if (.not. ieee_is_finite(y) .or. abs(y - expected) > 1.0e-6) error stop 1
  if (abs(yd - expected*(-0.5*xd(1))) > 1.0e-6) error stop 2

  yb = 1.7
  call v128_vjp(2, x, y, yb, xb)
  if (abs(xb(1) - yb*(-0.5*expected)) > 1.0e-6) error stop 3
  if (abs(xb(2)) > 1.0e-6) error stop 4
  print '(a)', 'harness_status: pass'
end program check_v128
