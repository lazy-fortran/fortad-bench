! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh001/program.f at e59864c.
! The in-place writes are retained; the derivative contract treats i1, i2,
! and i3 as the initial independent state and o1 as the useful result.
subroutine set01_lh001(i1, i2, i3, o1, o2, o3)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: i1, i2
    real(dp), intent(in) :: i3
    real(dp), intent(out) :: o1, o2, o3
    call set01_lh001_sub1(i1, i2, o1, o2)
    o3 = i3*i2
    o1 = o1*o2*i2
    o3 = 2.0_dp
    i2 = 5.0_dp
end subroutine set01_lh001

subroutine set01_lh001_sub1(i1, i2, o1, o2)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: i1, i2
    real(dp), intent(out) :: o1, o2
    real(dp) :: l1, l2

    l1 = i1*i2
    l2 = i1 - 3.0_dp*i2
    o1 = l1/l2
    o2 = 35.0_dp
    i1 = 99.0_dp
end subroutine set01_lh001_sub1
