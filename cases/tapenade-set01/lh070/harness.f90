program tapenade_set01_lh070_harness
  use tapenade_set01_lh070_case, only: set01_lh070
  use tapenade_set01_lh070_hand, only: hand_value, hand_jvp
  use lh070_forward_mod, only: lh070_forward
  use lh070_reverse_y_mod, only: lh070_reverse_y
  implicit none

  real :: a(10), b(10), x, y, z
  real :: ad(10), bd(10), xd, yd, zd
  real :: ha(10), hb(10), hx, hy, hz
  real :: had(10), hbd(10), hxd, hyd, hzd
  real :: ab(10), bb(10), xb, zb
  real :: seed
  integer :: i

  do i = 1, 10
    a(i) = 0.1 * real(i)
    b(i) = -0.07 * real(i)
    ad(i) = 0.013 * real(i)
    bd(i) = -0.009 * real(i)
  end do
  x = 1.2
  y = -5.0
  z = 0.7
  xd = -0.23
  yd = 4.0
  zd = 0.31

  ha = a; hb = b; hx = x; hy = y; hz = z
  had = ad; hbd = bd; hxd = xd; hyd = yd; hzd = zd
  call hand_jvp(ha, had, hb, hbd, hx, hxd, hy, hyd, hz, hzd)
  call set01_lh070(a, b, x, y, z)
  if (maxval(abs([a - ha, b - hb, x - hx, y - hy, z - hz])) > 1.0e-6) then
    error stop "bounded primal mismatch"
  end if

  do i = 1, 10
    a(i) = 0.1 * real(i)
    b(i) = -0.07 * real(i)
  end do
  x = 1.2
  y = -5.0
  z = 0.7
  ad = [(0.013 * real(i), i = 1, 10)]
  bd = [(-0.009 * real(i), i = 1, 10)]
  xd = -0.23
  yd = 4.0
  zd = 0.31
  call lh070_forward(a, ad, b, bd, x, xd, y, yd, z, zd)
  if (maxval(abs([a - ha, b - hb, x - hx, y - hy, z - hz, &
      ad - had, bd - hbd, xd - hxd, yd - hyd, zd - hzd])) > 2.0e-5) then
    error stop "bounded forward mismatch"
  end if

  do i = 1, 10
    a(i) = 0.1 * real(i)
    b(i) = -0.07 * real(i)
  end do
  x = 1.2
  y = -5.0
  z = 0.7
  seed = 0.8
  call lh070_reverse_y(a, b, x, y, z, seed, ab, bb, xb, zb)
  if (maxval(abs(ab)) > 2.0e-6 .or. maxval(abs(bb)) > 2.0e-6 .or. &
      abs(xb - seed * 0.7) > 2.0e-6 .or. abs(zb - seed * 1.2) > 2.0e-6) then
    error stop "bounded reverse mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'forward_y: ', y
  print '(a,es24.16)', 'reverse_x_b: ', xb
  print '(a,es24.16)', 'reverse_z_b: ', zb
end program tapenade_set01_lh070_harness
