! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh088/program.f at e59864c.
! The three sequential assignments are retained; `total` is an
! oracle-only aggregate so reverse mode can seed one scalar result.
subroutine set01_lh088(a, b, c, d, total)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(in) :: a, b, c, d
    real(dp), intent(out) :: total
    real(dp) :: a_out, b_out, c_out

    a_out = sqrt(b)
    b_out = log(c)
    c_out = c**d
    total = a_out + b_out + c_out
end subroutine set01_lh088
