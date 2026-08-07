program tapenade_set01_v101_harness
  use tapenade_set01_v101_hand, only: hand_jvp, hand_vjp
  use v101_forward_mod, only: head_v101_forward
  use v101_reverse_mod, only: head_v101_reverse
  implicit none

  double precision :: x(2), x_d(2), y(1), y_d(1)
  double precision :: hand_y(1), hand_y_d(1)
  double precision :: y_b(1), x_b(2), hand_x_b(2)
  double precision, parameter :: tol = 1.0d-12

  x = [1.25d0, -0.75d0]
  x_d = [0.17d0, -0.23d0]
  call hand_jvp(x, x_d, hand_y, hand_y_d)
  call head_v101_forward(x, x_d, y, y_d)
  if (maxval(abs([y - hand_y, y_d - hand_y_d])) > tol) then
    error stop "bounded forward mismatch"
  end if

  y_b = [0.61d0]
  call hand_vjp(x, y_b, hand_y, hand_x_b)
  call head_v101_reverse(x, y, y_b, x_b)
  if (maxval(abs([y - hand_y, x_b - hand_x_b])) > tol) then
    error stop "bounded reverse mismatch"
  end if

  if (abs(y(1) + 3.75d0) > tol .or. abs(y_d(1) + 1.66d0) > tol .or. &
      abs(x_b(1) + 1.83d0) > tol .or. abs(x_b(2) - 3.05d0) > tol) then
    error stop "bounded expected-value mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'forward_y: ', y(1)
  print '(a,es24.16)', 'forward_y_d: ', y_d(1)
  print '(a,es24.16)', 'reverse_x1_b: ', x_b(1)
  print '(a,es24.16)', 'reverse_x2_b: ', x_b(2)
end program tapenade_set01_v101_harness
