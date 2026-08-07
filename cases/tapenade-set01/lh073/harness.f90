program tapenade_set01_lh073_harness
  use tapenade_set01_lh073_case, only: set01_lh073
  use tapenade_set01_lh073_hand, only: hand_jvp
  use lh073_forward_mod, only: lh073_forward
  use lh073_reverse_mod, only: lh073_reverse
  implicit none

  real :: a_in(10), a_in_d(10), b_in(10), b_in_d(10)
  real :: a_out(10), a_out_d(10), b_out(10), b_out_d(10)
  real :: ha_out(10), ha_out_d(10), hb_out(10), hb_out_d(10)
  real :: fa_out(10), fa_out_d(10), fb_out(10), fb_out_d(10)
  real :: objective, objective_d, hobjective, hobjective_d
  real :: fobjective, fobjective_d, objective_seed
  real :: reverse_a_out(10), reverse_b_out(10)
  real :: a_in_b(10), b_in_b(10), expected_a_b(10), expected_b_b(10)
  real :: tolerance
  integer :: i

  do i = 1, 10
    a_in(i) = 0.17 * real(i) - 0.4
    a_in_d(i) = -0.021 * real(i) + 0.11
    b_in(i) = 0.08 * real(i) + 0.35
    b_in_d(i) = 0.017 * real(i) - 0.05
  end do
  tolerance = 3.0e-5

  call hand_jvp(a_in, a_in_d, b_in, b_in_d, ha_out, ha_out_d, hb_out, &
      hb_out_d, hobjective, hobjective_d)
  call set01_lh073(a_in, b_in, a_out, b_out, objective)
  if (maxval(abs(a_out - ha_out)) > tolerance .or. &
      maxval(abs(b_out - hb_out)) > tolerance .or. &
      abs(objective - hobjective) > tolerance) then
    error stop "bounded primal mismatch"
  end if

  call lh073_forward(a_in, a_in_d, b_in, b_in_d, fa_out, fa_out_d, &
      fb_out, fb_out_d, fobjective, fobjective_d)
  if (maxval(abs(fa_out - ha_out)) > tolerance .or. &
      maxval(abs(fa_out_d - ha_out_d)) > tolerance .or. &
      maxval(abs(fb_out - hb_out)) > tolerance .or. &
      maxval(abs(fb_out_d - hb_out_d)) > tolerance .or. &
      abs(fobjective - hobjective) > tolerance .or. &
      abs(fobjective_d - hobjective_d) > tolerance) then
    error stop "bounded forward mismatch"
  end if

  objective_seed = 0.73
  call lh073_reverse(a_in, b_in, reverse_a_out, reverse_b_out, objective_seed, &
      a_in_b, b_in_b)
  do i = 1, 10
    expected_a_b(i) = objective_seed * b_in(i)
    if (i == 10) then
      expected_b_b(i) = objective_seed * (a_in(i) + 4.0 * b_in(i)**3)
    else
      expected_b_b(i) = objective_seed * (a_in(i) + 2.0 * b_in(i))
    end if
  end do
  if (maxval(abs(reverse_a_out - ha_out)) > tolerance .or. &
      maxval(abs(reverse_b_out - hb_out)) > tolerance .or. &
      maxval(abs(a_in_b - expected_a_b)) > tolerance .or. &
      maxval(abs(b_in_b - expected_b_b)) > tolerance) then
    error stop "bounded reverse mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'objective: ', objective
  print '(a,es24.16)', 'objective_jvp: ', hobjective_d
  print '(a,es24.16)', 'objective_reverse_a1: ', a_in_b(1)
  print '(a,es24.16)', 'objective_reverse_b10: ', b_in_b(10)
end program tapenade_set01_lh073_harness
