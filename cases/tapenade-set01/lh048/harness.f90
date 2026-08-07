program tapenade_set01_lh048_harness
  use tapenade_set01_lh048_case, only: set01_lh048
  use tapenade_set01_lh048_hand, only: hand_value
  use lh048_forward_ad, only: lh048
  implicit none

  real :: u, z, t, v, y, ud, zd, td, vd, yd
  real :: u_port, z_port, t_port, v_port, y_port
  real :: x(14), x_initial(14), x_ref(14), x_ad(14), xd(14)
  real :: u_ref, z_ref, t_ref, v_ref, y_ref
  integer :: i

  u = 1.2
  z = 0.7
  t = -0.4
  v = 0.3
  y = 2.0
  do i = 1, 14
    x(i) = 0.1 * real(i)
  end do
  x_initial = x
  x_ref = x_initial
  u_ref = u
  z_ref = z
  t_ref = t
  v_ref = v
  y_ref = y
  call hand_value(u_ref, z_ref, t_ref, v_ref, x_ref, y_ref)

  u_port = u
  z_port = z
  t_port = t
  v_port = v
  y_port = y
  call set01_lh048(u_port, z_port, t_port, v_port, x, y_port)

  x_ad = x_initial
  ud = 0.2
  zd = -0.1
  td = 0.4
  vd = 0.3
  yd = 0.0
  xd = 0.0
  call lh048(u, ud, z, zd, t, td, v, vd, x_ad, xd, y, yd)

  if (abs(t_port - t_ref) > 2.0e-5 .or. abs(u_port - u_ref) > 2.0e-5 .or. &
      abs(v_port - v_ref) > 2.0e-5 .or. abs(y_port - y_ref) > 2.0e-5 .or. &
      maxval(abs(x - x_ref)) > 2.0e-5) then
    error stop "bounded port disagrees with independent hand evaluation"
  end if
  print '(a)', 'oracle_status: pass'
end program tapenade_set01_lh048_harness
