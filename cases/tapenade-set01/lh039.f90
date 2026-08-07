! Port of Tapenade nonRegressions/set01/lh039/program.f at
! e59864cab441d4175df75383b3ff58c3dcd26df9.
! The port keeps the two subroutine calls and the in-place input writes.
subroutine set01_lh039(i1, i2, i3, o1, o2, o3)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    real(dp) :: i1, i2, i3, o1, o2, o3

    o3 = i2 * i3
    call sub1(i1, i2, o1, o2)
    o1 = o1 * o2 * i2
    o3 = 2.0_dp
    i2 = 5.0_dp
end subroutine set01_lh039

subroutine sub1(i1, i2, o1, o2)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    real(dp) :: i1, i2, o1, o2
    real(dp) :: l1, l2

    l1 = i1 * i2
    l2 = i1 - 3.0_dp * i2
    o1 = l1 / l2
    o2 = 35.0_dp
    i1 = 99.0_dp
end subroutine sub1
