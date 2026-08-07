program tapenade_set01_lh077_harness
  use tapenade_set01_lh077_case, only: set01_lh077
  use tapenade_set01_lh077_hand, only: hand_value, hand_jvp, hand_vjp
  use lh077_forward_mod, only: lh077_forward
  use lh077_reverse_mod, only: lh077_reverse
  implicit none

  real :: a(100), b, c, c_out
  real :: ad(100), bd, cd, c_outd
  real :: ha(100), hb, hc, hc_out, h_c_outd
  real :: hab(100), hbb, hcb, hseed
  real :: ab(100), bb, cb
  integer :: i

  do i = 1, 100
    a(i) = 0.01 * real(i)
    ad(i) = (-1.0)**i * 0.003 * real(i)
  end do
  b = 1.7
  c = -0.4
  bd = 0.17
  cd = -0.23

  ha = a
  hb = b
  hc = c
  call hand_value(ha, hb, hc, hc_out)
  call set01_lh077(a, b, c, c_out)
  if (abs(c_out - hc_out) > 2.0e-5) error stop "bounded primal mismatch"

  call hand_jvp(ha, ad, hb, bd, hc, cd, hc_out, h_c_outd)
  call lh077_forward(a, ad, b, bd, c, cd, c_out, c_outd)
  if (abs(c_out - hc_out) > 2.0e-5 .or. abs(c_outd - h_c_outd) > 2.0e-5) then
    error stop "bounded forward mismatch"
  end if

  hseed = 0.61
  call hand_vjp(a, b, c, hseed, hab, hbb, hcb)
  call lh077_reverse(a, b, c, c_out, hseed, ab, bb, cb)
  if (maxval(abs(ab - hab)) > 2.0e-5 .or. abs(bb - hbb) > 2.0e-5 .or. &
      abs(cb - hcb) > 2.0e-5) then
    error stop "bounded reverse mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'value: ', c_out
  print '(a,es24.16)', 'forward: ', c_outd
  print '(a,es24.16)', 'reverse_b: ', bb
  print '(a,es24.16)', 'reverse_c: ', cb
end program tapenade_set01_lh077_harness
