program lh148_harness
  use module1, only: toto
  use lh148_forward, only: lh148_jvp
  use lh148_reverse, only: lh148_vjp
  implicit none

  real :: a, b, c, d
  real :: a_d, b_d, c_d, d_d
  real :: d_b, a_b, b_b, c_b

  a = 2.0
  b = -3.0
  c = 0.5
  a_d = 0.25
  b_d = -0.5
  c_d = 1.25

  call toto(a, b, c, d)
  if (abs(d - (-3.0)) > 1.0e-5) error stop "primal mismatch"

  d_d = 0.0
  call lh148_jvp(a, a_d, b, b_d, c, c_d, d, d_d)
  if (abs(d_d - (-8.375)) > 1.0e-5) error stop "forward mismatch"

  d_b = 0.75
  call lh148_vjp(a, b, c, d, d_b, a_b, b_b, c_b)
  if (abs(a_b - (-1.125)) > 1.0e-5) error stop "reverse a mismatch"
  if (abs(b_b - 0.75) > 1.0e-5) error stop "reverse b mismatch"
  if (abs(c_b - (-4.5)) > 1.0e-5) error stop "reverse c mismatch"

  write (*, '(a)') "harness_status: pass"
end program lh148_harness
