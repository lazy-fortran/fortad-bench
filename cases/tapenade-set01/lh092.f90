! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh092/program.f at e59864c.
subroutine set01_lh092(a, b, c)
    implicit none
    real(8), intent(in) :: a, b
    real(8), intent(out) :: c
    real(8) :: d, x

    d = 2.0d0*a - b
    x = 1.0d0 - d
    c = x*x
end subroutine set01_lh092
