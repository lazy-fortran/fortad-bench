program tapenade_set05_v064_harness
  use tapenade_set05_v064, only: mppsum_real
  use tapenade_set05_v064_hand, only: mppsum_real_hand, &
      mppsum_real_jvp_hand, mppsum_real_vjp_hand
  use tapenade_set05_v064_forward, only: v064_jvp
  use tapenade_set05_v064_reverse, only: v064_vjp
  implicit none
  double precision :: ptab, ptab_d, value, value_d
  double precision :: ptab_b, value_b, hand_value, hand_value_d, hand_ptab_b

  ptab = 3.25d0
  ptab_d = -0.75d0
  value_b = 0.8d0

  value = mppsum_real(ptab)
  hand_value = mppsum_real_hand(ptab)
  if (abs(value - hand_value) > 1.0d-12) error stop 'primal mismatch'

  call v064_jvp(ptab, ptab_d, value, value_d)
  call mppsum_real_jvp_hand(ptab, ptab_d, hand_value, hand_value_d)
  if (abs(value - hand_value) > 1.0d-12) error stop 'forward primal mismatch'
  if (abs(value_d - hand_value_d) > 1.0d-12) error stop 'forward mismatch'

  call v064_vjp(ptab, value, value_b, ptab_b)
  call mppsum_real_vjp_hand(ptab, value_b, hand_ptab_b)
  if (abs(ptab_b - hand_ptab_b) > 1.0d-12) error stop 'reverse mismatch'

  write (*, '(a)') 'harness_status: pass'
end program tapenade_set05_v064_harness
