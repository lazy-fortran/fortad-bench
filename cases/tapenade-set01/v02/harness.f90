program tapenade_set01_v02_harness
  use tapenade_set01_v02_case, only: top_v02
  use tapenade_set01_v02_hand, only: hand_jvp
  use v02_forward_mod, only: top_v02_forward
  use v02_reverse_mod, only: top_v02_reverse_o1
  implicit none

  real :: i2, i3, o1, o2, o3
  real :: i2d, i3d, o1d, o3d
  real :: hi3, ho1, ho2, ho3, hi3d, ho1d, ho3d
  real :: ri3, ro1, ro2, ro3, ri2b, ri3b
  real, parameter :: tol = 4.0e-5

  i2 = 1.1
  i3 = 0.8
  i2d = 0.037
  i3d = -0.061
  hi3 = i3
  hi3d = i3d
  call hand_jvp(i2, i2d, hi3, hi3d, ho1, ho1d, ho2, ho3, ho3d)
  call top_v02_forward(i2, i2d, i3, i3d, o1, o1d, o2, o3, o3d)
  if (maxval(abs([i3 - hi3, o1 - ho1, o2 - ho2, o3 - ho3, &
      i3d - hi3d, o1d - ho1d, o3d - ho3d])) > tol) then
    error stop "bounded forward mismatch"
  end if

  ri3 = 0.8
  call top_v02_reverse_o1(1.1, ri3, ro1, ro2, ro3, 0.8, ri2b, ri3b)
  if (abs(ro1 - 89.7575) > tol .or. abs(ri2b - 24.6866667) > tol .or. &
      abs(ri3b + 24.6866667) > tol) then
    error stop "bounded reverse mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'forward_o1: ', o1
  print '(a,es24.16)', 'forward_o1d: ', o1d
  print '(a,es24.16)', 'reverse_i2_b: ', ri2b
  print '(a,es24.16)', 'reverse_i3_b: ', ri3b
end program tapenade_set01_v02_harness
