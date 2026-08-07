program lh055_harness
  use iso_fortran_env, only: real64
  use lh055_forward_mod, only: lh055_forward
  use lh055_reverse_mod, only: lh055_reverse
  implicit none

  real(real64) :: a, ad, b, bd, ab, bb
  real(real64), parameter :: expected = 3.315_real64
  real(real64), parameter :: expected_d = -1.2775_real64
  real(real64), parameter :: tolerance = 2.0e-12_real64

  b = 1.7_real64
  bd = -0.35_real64
  call lh055_forward(a, ad, b, bd)
  if (abs(a - expected) > tolerance .or. abs(ad - expected_d) > tolerance) then
    error stop "forward harness mismatch"
  end if

  ab = 0.8_real64
  bb = 0.0_real64
  call lh055_reverse(a, b, ab, bb)
  if (abs(a - expected) > tolerance .or. abs(bb - 2.92_real64) > tolerance) then
    error stop "reverse harness mismatch"
  end if
  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'forward_value: ', a
  print '(a,es24.16)', 'forward_derivative: ', ad
  print '(a,es24.16)', 'reverse_input_adjoint: ', bb
end program lh055_harness
