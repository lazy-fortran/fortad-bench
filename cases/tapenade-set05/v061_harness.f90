program tapenade_set05_v061_harness
  use tapenade_set05_v061, only: func
  use tapenade_set05_v061_hand, only: func_hand, func_jvp_hand, func_vjp_hand
  use tapenade_set05_v061_forward, only: v061_jvp
  use tapenade_set05_v061_reverse, only: v061_vjp
  implicit none
  real :: t, u, value, value_d, t_d, u_d
  real :: t_b, u_b, seed

  t = 3.0
  u = -1.0
  t_d = 0.25
  u_d = -0.75
  seed = 0.8

  value = func(t, u)
  if (abs(value - func_hand(t, u)) > 1.0e-6) error stop 'primal mismatch'

  value_d = 0.0
  call v061_jvp(t, t_d, u, u_d, value, value_d)
  if (abs(value_d - func_jvp_hand(t_d, u_d)) > 1.0e-6) error stop 'forward mismatch'

  call v061_vjp(t, u, value, seed, t_b, u_b)
  call func_vjp_hand(seed, t_d, u_d)
  if (abs(t_b - t_d) > 1.0e-6) error stop 'reverse t mismatch'
  if (abs(u_b - u_d) > 1.0e-6) error stop 'reverse u mismatch'

  write (*, '(a)') 'harness_status: pass'
end program tapenade_set05_v061_harness
