program v100_harness
  use v100_forward_mod, only: head_v100_forward
  use v100_reverse_mod, only: head_v100_reverse
  implicit none

  double precision :: x_in(1), x_in_d(1), x_out(1), x_out_d(1)
  double precision :: y(1), y_d(1), y_b(1), x_in_b(1)
  double precision :: hx_in(1), hx_in_d(1), hx_out(1), hx_out_d(1)
  double precision :: hy(1), hy_d(1), hy_b(1), hx_in_b(1)

  x_in = 0.25D0
  x_in_d = 0.03D0
  x_out = 0.0D0
  x_out_d = 0.0D0
  y = 0.0D0
  y_d = 0.0D0
  call head_v100_forward(x_in, x_in_d, x_out, x_out_d, y, y_d)
  if (abs(x_out(1) - 2.5D0) > 1.0D-12) error stop 1
  if (abs(y(1) - 0.5D0) > 1.0D-12) error stop 2
  if (abs(x_in_d(1) - 0.03D0) > 1.0D-12) error stop 3
  if (abs(x_out_d(1) - 0.3D0) > 1.0D-12) error stop 4
  if (abs(y_d(1) - 0.3D0) > 1.0D-12) error stop 5

  hx_in = 0.25D0
  hx_in_d = 0.03D0
  hx_out = 0.0D0
  hx_out_d = 0.0D0
  hy = 0.0D0
  hy_d = 0.0D0
  call head_v100_hand_forward(hx_in, hx_in_d, hx_out, hx_out_d, hy, hy_d)
  if (maxval(abs(x_out - hx_out)) > 1.0D-12) error stop 6
  if (maxval(abs(y - hy)) > 1.0D-12) error stop 7
  if (maxval(abs(x_out_d - hx_out_d)) > 1.0D-12) error stop 8
  if (maxval(abs(y_d - hy_d)) > 1.0D-12) error stop 9

  x_in = 0.25D0
  x_out = 0.0D0
  y = 0.0D0
  y_b = 1.0D0
  x_in_b = 0.0D0
  call head_v100_reverse(x_in, x_out, y, y_b, x_in_b)
  if (abs(x_in_b(1) - 10.0D0) > 1.0D-12) error stop 10

  hx_in = 0.25D0
  hx_out = 0.0D0
  hy = 0.0D0
  hy_b = 1.0D0
  hx_in_b = 0.0D0
  call head_v100_hand_reverse(hx_in, hx_out, hy, hy_b, hx_in_b)
  if (maxval(abs(x_in_b - hx_in_b)) > 1.0D-12) error stop 11

  print '(A)', 'harness_status: pass'
end program v100_harness
