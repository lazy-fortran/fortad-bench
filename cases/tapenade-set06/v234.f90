! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Callable port of Tapenade nonRegressions/set06/v234/program.f90 at
! e59864cab441d4175df75383b3ff58c3dcd26df9.  The upstream function is
! contained in PROGRAM TEST; this port exposes that function as a routine
! suitable for standalone differentiation.
subroutine set06_v234(t, f)
    implicit none
    real, intent(in) :: t
    real, intent(out) :: f

    f = t*t
end subroutine set06_v234
