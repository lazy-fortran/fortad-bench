program tapenade_set01_lh038_harness
  use tapenade_set01_lh038_case, only: set01_lh038
  use tapenade_set01_lh038_hand, only: hand_jvp, hand_value
  use lh038_forward_ad, only: lh038_forward
  implicit none

  real :: pi, pi_d, x, x_d, x_d0, expected, expected_d
  real :: x_ref, x_ad
  integer :: i

  do i = 1, 2
    if (i == 1) then
      pi = 3.14
      pi_d = 0.7
      x = 10.0
      x_d = 0.3
    else
      pi = 3.14
      pi_d = 0.7
      x = 25.0
      x_d = 0.3
    end if

    x_d0 = x_d
    x_ref = x
    call set01_lh038(pi, x_ref)
    x_ad = x
    call lh038_forward(pi, pi_d, x_ad, x_d)
    expected = hand_value(pi, x)
    expected_d = hand_jvp(pi, x, pi_d, x_d0)

    if (abs(x_ref - expected) > 1.0e-5 .or. &
        abs(x_ad - expected) > 1.0e-5 .or. &
        abs(x_d - expected_d) > 1.0e-5) then
      error stop "independent hand/JVP mismatch"
    end if
  end do

  print '(a)', 'oracle_status: pass'
end program tapenade_set01_lh038_harness
