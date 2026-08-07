program tapenade_set05_v065_harness
  use tapenade_set05_v065, only: mppsum_real2_value
  use tapenade_set05_v065_hand, only: mppsum_real2_value_hand, &
      mppsum_real2_value_jvp_hand, mppsum_real2_value_vjp_hand
  use tapenade_set05_v065_forward, only: v065_jvp
  use tapenade_set05_v065_reverse, only: v065_vjp
  implicit none
  double precision :: ptab(10), ptab_d(10), value(10), value_d(10)
  double precision :: cst, value_b(10), ptab_b(10)
  double precision :: hand_value(10), hand_value_d(10), hand_ptab_b(10)
  integer :: i

  do i = 1, 10
    ptab(i) = 0.25d0 * dble(i) - 1.5d0
    ptab_d(i) = (-1.0d0)**i * 0.1d0 * dble(i)
    value_b(i) = 0.05d0 * dble(i) - 0.2d0
  end do
  cst = 1.75d0

  call mppsum_real2_value(ptab, cst, value)
  call mppsum_real2_value_hand(ptab, cst, hand_value)
  if (maxval(abs(value - hand_value)) > 1.0d-12) error stop 'primal mismatch'

  call v065_jvp(ptab, ptab_d, cst, value, value_d)
  call mppsum_real2_value_jvp_hand(ptab, ptab_d, cst, hand_value, hand_value_d)
  if (maxval(abs(value - hand_value)) > 1.0d-12) error stop 'forward primal mismatch'
  if (maxval(abs(value_d - hand_value_d)) > 1.0d-12) error stop 'forward mismatch'

  call v065_vjp(ptab, cst, value, value_b, ptab_b)
  call mppsum_real2_value_vjp_hand(ptab, cst, value, value_b, hand_ptab_b)
  if (maxval(abs(value - hand_value)) > 1.0d-12) error stop 'reverse primal mismatch'
  if (maxval(abs(ptab_b - hand_ptab_b)) > 1.0d-12) error stop 'reverse array mismatch'

  write (*, '(a)') 'harness_status: pass'
end program tapenade_set05_v065_harness
