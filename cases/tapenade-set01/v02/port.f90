module tapenade_set01_v02_case
  implicit none
contains

  subroutine top_v02(i2_in, i3, o1, o2, o3)
    real, intent(in) :: i2_in
    real, intent(inout) :: i3
    real, intent(out) :: o1, o2, o3
    real :: state, i1, x1

    state = i2_in
    i1 = 2.0
    if (i3 .lt. 0.0) i3 = i1 - state
    i1 = state - i3
    state = 2.3
    x1 = i1 - i3
    o3 = i3 * state
    call sub1_v02(i1, o1, o2, state)
    o1 = o1 * o2 * state
    o3 = 2.0
    state = 5.0
  end subroutine top_v02

  subroutine sub1_v02(i1, o1, o2, state)
    real, intent(inout) :: i1
    real, intent(out) :: o1, o2
    real, intent(in) :: state
    real :: x1, x2

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
  end subroutine sub1_v02

end module tapenade_set01_v02_case
