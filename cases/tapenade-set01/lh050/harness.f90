program tapenade_set01_lh050_harness
  use tapenade_set01_lh050_hand, only: hand_value, hand_jvp, hand_vjp_z
  use lh050_exact_forward_mod, only: lh050_exact_forward
  use lh050_exact_reverse_mod, only: lh050_exact_reverse
  use lh050_port_forward_mod, only: lh050_port_forward
  implicit none

  real :: x, y, z, x_d, y_d, z_d
  real :: y_expected, z_expected, y_d_expected, z_d_expected
  real :: exact_y, exact_z, exact_y_d
  real :: exact_x_b, exact_y_b, expected_x_b, expected_y_b
  real, parameter :: tol = 1.0e-5

  x = 2.0
  y = 3.0
  z = 7.0
  x_d = 0.2
  y_d = 0.4
  z_d = 0.5
  call hand_value(x, y, z, y_expected, z_expected)
  call hand_jvp(x, y, z, x_d, y_d, z_d, y_d_expected, z_d_expected)

  exact_y = y
  exact_z = z
  exact_y_d = y_d
  call lh050_exact_forward(x, x_d, exact_y, exact_y_d, exact_z)
  if (abs(exact_y - y_expected) < tol .and. &
      abs(exact_z - z_expected) < tol .and. &
      abs(exact_y_d - y_d_expected) < tol) then
    error stop 'exact FortAD forward unexpectedly matched the oracle'
  end if
  print '(a)', 'exact_forward_oracle: mismatch'

  exact_y = y
  exact_z = z
  exact_x_b = 0.0
  exact_y_b = 0.0
  call lh050_exact_reverse(x, exact_y, exact_z, 1.0, exact_x_b, exact_y_b)
  call hand_vjp_z(x, y, 1.0, expected_x_b, expected_y_b)
  if (abs(exact_x_b - expected_x_b) < tol .and. &
      abs(exact_y_b - expected_y_b) < tol) then
    error stop 'exact FortAD reverse unexpectedly matched the oracle'
  end if
  print '(a)', 'exact_reverse_oracle: mismatch'

  y = 3.0
  z = 7.0
  y_d = 0.4
  z_d = 0.5
  call lh050_port_forward(x, x_d, y, y_d, z, z_d)
  if (abs(y - y_expected) > tol .or. abs(z - z_expected) > tol .or. &
      abs(y_d - y_d_expected) > tol .or. abs(z_d - z_d_expected) > tol) then
    error stop 'bounded FortAD forward mismatch'
  end if
  print '(a)', 'bounded_forward_oracle: pass'
  print '(a)', 'oracle_status: pass'
end program tapenade_set01_lh050_harness
