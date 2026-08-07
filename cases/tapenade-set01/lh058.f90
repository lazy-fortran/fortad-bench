! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh058/program.f at e59864c.
! The computation is unchanged; names, intents, and real64 kinds are explicit.
subroutine set01_lh058(t, u, n, e)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: t(:), u(:)
    integer, intent(in) :: n
    real(dp), intent(out) :: e
    real(dp) :: e1, e2
    integer :: i

    e2 = 0.0_dp
    do i = 1, n
        e1 = t(i) - u(i)
        e2 = e2 + e1**2
    end do
    e = sqrt(e2)
end subroutine set01_lh058
