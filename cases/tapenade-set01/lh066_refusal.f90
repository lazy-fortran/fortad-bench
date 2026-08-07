! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Exact source shape for the lh066 refusal boundary.  The original routine
! mutates an independent `a` in place and has no intent(out) dependent.
subroutine set01_lh066_refusal(a, b)
    implicit none
    real, intent(inout) :: a
    real, intent(in) :: b

    a = a/(3.0 - b)
end subroutine set01_lh066_refusal
