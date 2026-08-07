module tapenade_set01_v02_hand
  implicit none
contains

  subroutine hand_value(i2_in, i3, o1, o2, o3)
    real, intent(in) :: i2_in
    real, intent(inout) :: i3
    real, intent(out) :: o1, o2, o3
    real :: state, i1, x1, x2

    state = i2_in
    i1 = 2.0
    if (i3 .lt. 0.0) i3 = i1 - state
    i1 = state - i3
    state = 2.3
    x1 = i1 - i3
    o3 = i3 * state
    x2 = 5.0
    x1 = i1 * state
    if (i1 .gt. 3.0) then
      x2 = x2 + i1 - 3.0 * state
    else
      x2 = 12.0
      x1 = 2.0 * x1 + x2
    end if
    o1 = x1 / x2
    o2 = 35.0
    i1 = 99.0
    o1 = o1 * o2 * state
    o3 = 2.0
  end subroutine hand_value

  subroutine hand_jvp(i2_in, i2d, i3, i3d, o1, o1d, o2, o3, o3d)
    real, intent(in) :: i2_in
    real, intent(in) :: i2d
    real, intent(inout) :: i3, i3d
    real, intent(out) :: o1, o1d, o2, o3, o3d
    real :: state, i1, x1, x2
    real :: stated, i1d, x1d, x2d

    state = i2_in
    stated = i2d
    i1 = 2.0
    i1d = 0.0
    if (i3 .lt. 0.0) then
      i3d = -stated
      i3 = i1 - state
    end if
    i1 = state - i3
    i1d = stated - i3d
    state = 2.3
    stated = 0.0
    x1 = i1 - i3
    x1d = i1d - i3d
    o3d = i3d * state
    o3 = i3 * state
    x2 = 5.0
    x2d = 0.0
    x1d = i1d * state
    x1 = i1 * state
    if (i1 .gt. 3.0) then
      x2d = x2d + i1d - 3.0 * stated
      x2 = x2 + i1 - 3.0 * state
    else
      x2 = 12.0
      x2d = 0.0
      x1d = 2.0 * x1d
      x1 = 2.0 * x1 + x2
    end if
    o1d = 35.0 * state * (x1d * x2 - x1 * x2d) / (x2 * x2)
    o1 = 35.0 * state * x1 / x2
    o2 = 35.0
    o3d = 0.0
    o3 = 2.0
  end subroutine hand_jvp

end module tapenade_set01_v02_hand
