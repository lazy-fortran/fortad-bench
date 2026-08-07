program tapenade_bd11_harness
  use tapenade_bd11_case, only: top_bd11
  use bd11_hand, only: hand_jvp
  use bd11_forward_ad, only: bd11_jvp
  use bd11_reverse_ad, only: bd11_vjp
  implicit none

  real :: i1(10, 10), i2(10), i3(10), objective
  real :: i1_initial(10, 10), i2_initial(10), i3_initial(10)
  real :: i1d(10, 10), i2d(10), i3d(10), objectived
  real :: hi1(10, 10), hi2(10), hi3(10), hobjective
  real :: hi1d(10, 10), hi2d(10), hi3d(10), hobjectived
  real :: i1b(10, 10), i2b(10), i3b(10), objectiveb
  real :: expected_i3b(10)
  integer :: i, j

  do i = 1, 10
    i3_initial(i) = 0.35 + 0.08 * real(i - 1)
    i2_initial(i) = -0.11 * real(i)
    do j = 1, 10
      i1_initial(j, i) = 0.07 * real(j + 10 * (i - 1))
    end do
  end do
  do i = 1, 10
    i3d(i) = 0.013 * (-1.0)**(i + 100)
    i2d(i) = 0.013 * (-1.0)**i * real(100 + i)
    do j = 1, 10
      i1d(j, i) = 0.013 * (-1.0)**(j + i) * real(j + 10 * (i - 1))
    end do
  end do

  i1 = i1_initial; i2 = i2_initial; i3 = i3_initial
  hi1 = i1; hi2 = i2; hi3 = i3
  hi1d = i1d; hi2d = i2d; hi3d = i3d
  call hand_jvp(hi1, hi1d, hi2, hi2d, hi3, hi3d, hobjective, hobjectived)
  call top_bd11(i1, i2, i3, objective)
  if (maxval(abs(i1 - hi1)) > 2.0e-5 .or. &
      maxval(abs(i2 - hi2)) > 2.0e-5 .or. &
      maxval(abs(i3 - hi3)) > 2.0e-5 .or. &
      abs(objective - hobjective) > 2.0e-5) then
    error stop "bounded primal mismatch"
  end if

  i1 = i1_initial; i2 = i2_initial; i3 = i3_initial
  call bd11_jvp(i1, i1d, i2, i2d, i3, i3d, objective, objectived)
  if (maxval(abs(i1 - hi1)) > 2.0e-5 .or. &
      maxval(abs(i2 - hi2)) > 2.0e-5 .or. &
      maxval(abs(i3 - hi3)) > 2.0e-5 .or. &
      abs(objective - hobjective) > 2.0e-5 .or. &
      maxval(abs(i1d - hi1d)) > 3.0e-4 .or. &
      maxval(abs(i2d - hi2d)) > 3.0e-4 .or. &
      maxval(abs(i3d - hi3d)) > 3.0e-4 .or. &
      abs(objectived - hobjectived) > 3.0e-4) then
    error stop "bounded forward mismatch"
  end if

  i1 = i1_initial; i2 = i2_initial; i3 = i3_initial
  objectiveb = 0.8
  expected_i3b = 0.0
  expected_i3b(1) = objectiveb * 1.5 * sqrt(i3_initial(1))
  i1b = 0.0; i2b = 0.0; i3b = 0.0
  call bd11_vjp(i1, i2, i3, objective, objectiveb, i1b, i2b, i3b)
  if (maxval(abs(i1b)) > 3.0e-5 .or. &
      maxval(abs(i2b)) > 3.0e-5 .or. &
      maxval(abs(i3b - expected_i3b)) > 3.0e-5) then
    error stop "bounded reverse mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'objective: ', objective
  print '(a,es24.16)', 'objective_b: ', objectiveb
  print '(a,es24.16)', 'i3_b_first: ', i3b(1)
end program tapenade_bd11_harness
